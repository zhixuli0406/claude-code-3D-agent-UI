import SceneKit

/// Animation played when a completed team is being disbanded.
/// Characters shrink, float upward, and fade out with particle sparkles.
struct DisbandAnimation {
    static let key = "disbandAnimation"

    /// Duration of the full disband animation
    static let duration: TimeInterval = 1.5

    /// Apply the disband animation to a character node.
    /// On completion, the character is removed from its parent.
    static func apply(to character: VoxelCharacterNode, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        let totalDuration = duration

        // Add sparkle particles before dissolving
        let particles = buildSparkleParticles()
        particles.position = SCNVector3(0, 1.0, 0)
        character.addChildNode(particles)

        // Sequence: wait for stagger delay, then animate out
        let wait = SCNAction.wait(duration: delay)

        let dissolve = SCNAction.group([
            // Shrink
            SCNAction.scale(to: 0.01, duration: totalDuration),
            // Float upward
            SCNAction.moveBy(x: 0, y: 2.0, z: 0, duration: totalDuration),
            // Fade out
            SCNAction.fadeOut(duration: totalDuration)
        ])
        dissolve.timingMode = .easeIn

        let cleanup = SCNAction.run { node in
            node.removeFromParentNode()
            completion?()
        }

        character.runAction(.sequence([wait, dissolve, cleanup]), forKey: key)
    }

    static func remove(from character: VoxelCharacterNode) {
        character.removeAction(forKey: key)
    }

    // MARK: - Sparkle particles

    private static func buildSparkleParticles() -> SCNNode {
        let node = SCNNode()
        node.name = "disbandParticles"

        // Create small sparkle cubes that float upward
        let sparkleCount = 8
        for i in 0..<sparkleCount {
            let sparkle = SCNBox(width: 0.04, height: 0.04, length: 0.04, chamferRadius: 0.01)
            let material = SCNMaterial()
            let colors: [NSColor] = [
                NSColor(hex: "#FFD700"), // gold
                NSColor(hex: "#00BCD4"), // cyan
                NSColor(hex: "#FFFFFF"), // white
                NSColor(hex: "#4CAF50")  // green
            ]
            let color = colors[i % colors.count]
            material.diffuse.contents = color
            material.emission.contents = color
            material.emission.intensity = 0.8
            sparkle.materials = [material]

            let sparkleNode = SCNNode(geometry: sparkle)
            let angle = Float(i) / Float(sparkleCount) * Float.pi * 2
            let radius: Float = 0.3
            sparkleNode.position = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius)

            // Random upward float + fade
            let floatDuration = Double.random(in: 1.0...1.8)
            let floatUp = SCNAction.moveBy(x: CGFloat(Float.random(in: -0.5...0.5)),
                                           y: CGFloat(Float.random(in: 1.5...3.0)),
                                           z: CGFloat(Float.random(in: -0.5...0.5)),
                                           duration: floatDuration)
            floatUp.timingMode = .easeOut
            let fadeOut = SCNAction.fadeOut(duration: floatDuration)
            let spin = SCNAction.rotateBy(x: CGFloat.random(in: 1...4),
                                          y: CGFloat.random(in: 1...4),
                                          z: 0,
                                          duration: floatDuration)

            let waitDelay = SCNAction.wait(duration: Double.random(in: 0...0.3))
            sparkleNode.runAction(.sequence([
                waitDelay,
                .group([floatUp, fadeOut, spin]),
                .removeFromParentNode()
            ]))

            node.addChildNode(sparkleNode)
        }

        return node
    }
}
