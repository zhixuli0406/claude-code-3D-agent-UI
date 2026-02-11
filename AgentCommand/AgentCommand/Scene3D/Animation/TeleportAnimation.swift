import SceneKit

/// Animation played when agents teleport between themes during a scene transition.
/// Characters shrink into a glowing portal vortex, then reappear at their new position
/// with an expanding energy ring and particle burst.
struct TeleportAnimation {
    static let key = "teleportAnimation"

    /// Duration of the full teleport-out animation
    static let outDuration: TimeInterval = 0.7

    /// Duration of the full teleport-in animation
    static let inDuration: TimeInterval = 0.8

    // MARK: - Teleport Out (before scene rebuild)

    /// Play the teleport-out animation: agent spirals inward, shrinks, and vanishes
    /// into a glowing portal disc. Call `completion` when the agent is fully gone.
    static func playOut(
        on character: VoxelCharacterNode,
        delay: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) {
        let portalNode = buildPortalDisc()
        portalNode.position = SCNVector3(0, 0.05, 0)
        portalNode.opacity = 0
        character.addChildNode(portalNode)

        // Sparkle particles swirling inward
        let sparks = buildTeleportSparks(outward: false)
        sparks.position = SCNVector3(0, 1.0, 0)
        character.addChildNode(sparks)

        let wait = SCNAction.wait(duration: delay)

        // Portal disc fades in
        let portalFadeIn = SCNAction.fadeIn(duration: 0.15)
        portalNode.runAction(.sequence([wait, portalFadeIn]))

        // Spin the portal disc
        let portalSpin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 4, z: 0, duration: outDuration)
        portalNode.runAction(.sequence([wait, portalSpin]))

        // Agent spirals and shrinks
        let spinUp = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 3, z: 0, duration: outDuration)
        spinUp.timingMode = .easeIn
        let shrink = SCNAction.scale(to: 0.01, duration: outDuration)
        shrink.timingMode = .easeIn
        let moveDown = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: outDuration)
        moveDown.timingMode = .easeIn
        let fadeOut = SCNAction.fadeOut(duration: outDuration * 0.8)
        fadeOut.timingMode = .easeIn

        let dissolve = SCNAction.group([spinUp, shrink, moveDown, fadeOut])

        let cleanup = SCNAction.run { _ in
            completion?()
        }

        character.runAction(.sequence([wait, dissolve, cleanup]), forKey: key + "_out")
    }

    // MARK: - Teleport In (after scene rebuild)

    /// Play the teleport-in animation: agent materializes from a portal with
    /// an expanding energy ring and particle burst.
    static func playIn(
        on character: VoxelCharacterNode,
        delay: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) {
        // Save final state
        let finalScale = character.scale
        let finalOpacity = character.opacity

        // Start invisible and tiny
        character.scale = SCNVector3(0.01, 0.01, 0.01)
        character.opacity = 0

        // Portal disc at feet
        let portalNode = buildPortalDisc()
        portalNode.position = SCNVector3(0, 0.05, 0)
        character.addChildNode(portalNode)

        // Expanding energy ring
        let ring = buildEnergyRing()
        ring.position = SCNVector3(0, 0.1, 0)
        ring.opacity = 0
        character.addChildNode(ring)

        // Outward sparkle burst
        let sparks = buildTeleportSparks(outward: true)
        sparks.position = SCNVector3(0, 1.0, 0)
        sparks.opacity = 0
        character.addChildNode(sparks)

        let wait = SCNAction.wait(duration: delay)

        // Portal spins and fades out over the animation
        let portalSpin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 4, z: 0, duration: inDuration)
        let portalFade = SCNAction.sequence([
            .fadeIn(duration: 0.1),
            .wait(duration: inDuration * 0.5),
            .fadeOut(duration: inDuration * 0.4),
            .removeFromParentNode()
        ])
        portalNode.runAction(.sequence([wait, .group([portalSpin, portalFade])]))

        // Energy ring expands and fades
        ring.runAction(.sequence([
            wait,
            .wait(duration: inDuration * 0.2),
            .fadeIn(duration: 0.05),
            .group([
                .scale(to: 3.0, duration: inDuration * 0.6),
                .fadeOut(duration: inDuration * 0.6)
            ]),
            .removeFromParentNode()
        ]))

        // Sparks appear at halfway point
        sparks.runAction(.sequence([
            wait,
            .wait(duration: inDuration * 0.3),
            .fadeIn(duration: 0.05)
        ]))

        // Agent grows and fades in
        let scaleUp = SCNAction.scale(to: CGFloat(finalScale.x), duration: inDuration)
        scaleUp.timingMode = .easeOut
        let fadeIn = SCNAction.fadeOpacity(to: finalOpacity, duration: inDuration * 0.6)
        fadeIn.timingMode = .easeOut
        let spinIn = SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: inDuration)
        spinIn.timingMode = .easeOut

        let materialize = SCNAction.group([scaleUp, fadeIn, spinIn])

        let cleanup = SCNAction.run { _ in
            completion?()
        }

        character.runAction(.sequence([wait, materialize, cleanup]), forKey: key + "_in")
    }

    static func remove(from character: VoxelCharacterNode) {
        character.removeAction(forKey: key + "_out")
        character.removeAction(forKey: key + "_in")
    }

    // MARK: - Portal Disc

    private static func buildPortalDisc() -> SCNNode {
        let container = SCNNode()
        container.name = "teleportPortal"

        // Main disc
        let disc = SCNCylinder(radius: 0.6, height: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: "#7C4DFF").withAlphaComponent(0.6)
        mat.emission.contents = NSColor(hex: "#7C4DFF")
        mat.emission.intensity = 1.2
        mat.transparency = 0.7
        mat.isDoubleSided = true
        disc.materials = [mat]

        let discNode = SCNNode(geometry: disc)
        container.addChildNode(discNode)

        // Inner glow ring
        let innerRing = SCNTorus(ringRadius: 0.4, pipeRadius: 0.03)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(hex: "#00E5FF").withAlphaComponent(0.8)
        ringMat.emission.contents = NSColor(hex: "#00E5FF")
        ringMat.emission.intensity = 1.5
        innerRing.materials = [ringMat]

        let ringNode = SCNNode(geometry: innerRing)
        ringNode.position = SCNVector3(0, 0.02, 0)
        container.addChildNode(ringNode)

        // Outer glow ring
        let outerRing = SCNTorus(ringRadius: 0.6, pipeRadius: 0.02)
        let outerMat = SCNMaterial()
        outerMat.diffuse.contents = NSColor(hex: "#E040FB").withAlphaComponent(0.6)
        outerMat.emission.contents = NSColor(hex: "#E040FB")
        outerMat.emission.intensity = 1.0
        outerRing.materials = [outerMat]

        let outerRingNode = SCNNode(geometry: outerRing)
        outerRingNode.position = SCNVector3(0, 0.02, 0)
        container.addChildNode(outerRingNode)

        // Counter-rotate inner ring for visual interest
        let innerSpin = SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: 0.8)
        ringNode.runAction(.repeatForever(innerSpin))

        return container
    }

    // MARK: - Energy Ring

    private static func buildEnergyRing() -> SCNNode {
        let ring = SCNTorus(ringRadius: 0.3, pipeRadius: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: "#00E5FF").withAlphaComponent(0.7)
        mat.emission.contents = NSColor(hex: "#00E5FF")
        mat.emission.intensity = 1.5
        ring.materials = [mat]

        let node = SCNNode(geometry: ring)
        node.name = "teleportRing"
        return node
    }

    // MARK: - Teleport Sparks

    private static func buildTeleportSparks(outward: Bool) -> SCNNode {
        let container = SCNNode()
        container.name = "teleportSparks"

        let count = 10
        let colors: [NSColor] = [
            NSColor(hex: "#7C4DFF"), // purple
            NSColor(hex: "#00E5FF"), // cyan
            NSColor(hex: "#E040FB"), // magenta
            NSColor(hex: "#FFFFFF")  // white
        ]

        for i in 0..<count {
            let size: CGFloat = CGFloat.random(in: 0.02...0.04)
            let geo = SCNBox(width: size, height: size, length: size, chamferRadius: size * 0.3)
            let color = colors[i % colors.count]
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color
            mat.emission.intensity = 1.0
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            let angle = Float(i) / Float(count) * Float.pi * 2
            let radius: Float = outward ? 0.15 : 0.6

            node.position = SCNVector3(cos(angle) * radius, Float.random(in: -0.3...0.3), sin(angle) * radius)

            let duration = Double.random(in: 0.5...0.9)

            let moveAction: SCNAction
            if outward {
                // Explode outward
                moveAction = SCNAction.moveBy(
                    x: CGFloat(cos(angle) * Float.random(in: 0.8...1.5)),
                    y: CGFloat(Float.random(in: 0.5...1.5)),
                    z: CGFloat(sin(angle) * Float.random(in: 0.8...1.5)),
                    duration: duration
                )
            } else {
                // Spiral inward
                moveAction = SCNAction.move(
                    to: SCNVector3(0, Float.random(in: -0.2...0.2), 0),
                    duration: duration
                )
            }
            moveAction.timingMode = outward ? .easeOut : .easeIn

            let fadeOut = SCNAction.fadeOut(duration: duration * 0.8)
            let spin = SCNAction.rotateBy(
                x: CGFloat.random(in: 1...4),
                y: CGFloat.random(in: 1...4),
                z: 0,
                duration: duration
            )
            let shrink = SCNAction.scale(to: 0.1, duration: duration)
            shrink.timingMode = .easeIn

            let waitDelay = SCNAction.wait(duration: Double.random(in: 0...0.15))
            node.runAction(.sequence([
                waitDelay,
                .group([moveAction, fadeOut, spin, shrink]),
                .removeFromParentNode()
            ]))

            container.addChildNode(node)
        }

        // Auto-remove container
        container.runAction(.sequence([
            .wait(duration: 1.5),
            .removeFromParentNode()
        ]))

        return container
    }
}
