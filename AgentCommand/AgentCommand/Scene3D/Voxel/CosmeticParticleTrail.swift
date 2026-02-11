import SceneKit

/// Builds cosmetic particle trail effects that follow agents
enum CosmeticParticleTrail {

    static func buildTrail(colorHex: String, itemId: String) -> SCNNode {
        let node = SCNNode()
        node.name = "cosmeticParticle"

        let color = NSColor(hex: colorHex)

        // Determine style based on item
        switch itemId {
        case "particle_fire":
            buildFireTrail(node: node, color: color)
        case "particle_ice":
            buildIceTrail(node: node, color: color)
        case "particle_hearts":
            buildHeartsTrail(node: node, color: color)
        case "particle_lightning":
            buildLightningTrail(node: node, color: color)
        case "particle_rainbow":
            buildRainbowTrail(node: node)
        default:
            buildGenericTrail(node: node, color: color)
        }

        return node
    }

    // MARK: - Fire Trail

    private static func buildFireTrail(node: SCNNode, color: NSColor) {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 0.8
        material.blendMode = .add

        // Create multiple rising fire particles
        for i in 0..<6 {
            let particle = SCNSphere(radius: CGFloat.random(in: 0.02...0.04))
            particle.materials = [material]
            let pNode = SCNNode(geometry: particle)
            pNode.position = SCNVector3(
                Float.random(in: -0.3...0.3),
                0,
                Float.random(in: -0.3...0.3)
            )

            let rise = SCNAction.customAction(duration: 1.5) { n, elapsed in
                let t = Float(elapsed) / 1.5
                let phase = Float(i) * 0.3
                n.position = SCNVector3(
                    cos(t * Float.pi * 2 + phase) * 0.2,
                    t * 0.8,
                    sin(t * Float.pi * 2 + phase) * 0.2
                )
                n.opacity = CGFloat(1.0 - t)
                n.scale = SCNVector3(1.0 - t * 0.5, 1.0 - t * 0.5, 1.0 - t * 0.5)
            }
            pNode.runAction(.repeatForever(.sequence([rise, .moveBy(x: 0, y: -0.8, z: 0, duration: 0)])))
            node.addChildNode(pNode)
        }
    }

    // MARK: - Ice Trail

    private static func buildIceTrail(node: SCNNode, color: NSColor) {
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.6)
        material.emission.contents = color
        material.emission.intensity = 0.5
        material.blendMode = .add

        for i in 0..<8 {
            let crystal = SCNBox(width: 0.02, height: 0.04, length: 0.02, chamferRadius: 0)
            crystal.materials = [material]
            let cNode = SCNNode(geometry: crystal)

            let angle = Float(i) * Float.pi * 2 / 8
            let radius: Float = 0.4

            let orbit = SCNAction.customAction(duration: 3.0) { n, elapsed in
                let t = Float(elapsed) / 3.0
                let a = angle + t * Float.pi * 2
                n.position = SCNVector3(
                    cos(a) * radius,
                    sin(t * Float.pi * 4) * 0.15 + 0.5,
                    sin(a) * radius
                )
                n.eulerAngles = SCNVector3(t * Float.pi, t * Float.pi * 2, 0)
            }
            cNode.runAction(.repeatForever(orbit))
            node.addChildNode(cNode)
        }
    }

    // MARK: - Hearts Trail

    private static func buildHeartsTrail(node: SCNNode, color: NSColor) {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 0.6
        material.blendMode = .add

        for i in 0..<4 {
            let heart = SCNSphere(radius: 0.03)
            heart.materials = [material]
            let hNode = SCNNode(geometry: heart)

            let float = SCNAction.customAction(duration: 2.5) { n, elapsed in
                let t = Float(elapsed) / 2.5
                let phase = Float(i) * Float.pi * 0.5
                n.position = SCNVector3(
                    cos(t * Float.pi + phase) * 0.3,
                    t * 0.6 + 0.3,
                    sin(t * Float.pi * 2 + phase) * 0.15
                )
                n.opacity = CGFloat(sin(t * Float.pi))
                let s = 0.5 + sin(t * Float.pi) * 0.5
                n.scale = SCNVector3(s, s, s)
            }
            hNode.runAction(.repeatForever(.sequence([float, .moveBy(x: 0, y: -1, z: 0, duration: 0)])))
            node.addChildNode(hNode)
        }
    }

    // MARK: - Lightning Trail

    private static func buildLightningTrail(node: SCNNode, color: NSColor) {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 1.0
        material.blendMode = .add

        for i in 0..<5 {
            let bolt = SCNBox(width: 0.01, height: 0.15, length: 0.01, chamferRadius: 0)
            bolt.materials = [material]
            let bNode = SCNNode(geometry: bolt)

            let flash = SCNAction.customAction(duration: 0.8) { n, elapsed in
                let t = Float(elapsed) / 0.8
                let phase = Float(i) * 1.2
                n.position = SCNVector3(
                    cos(phase + t * Float.pi * 4) * 0.25,
                    0.5 + sin(t * Float.pi * 3) * 0.3,
                    sin(phase + t * Float.pi * 3) * 0.25
                )
                n.opacity = CGFloat(t < 0.1 || (t > 0.3 && t < 0.4) || (t > 0.7 && t < 0.8) ? 1.0 : 0.2)
                n.eulerAngles = SCNVector3(t * Float.pi, 0, Float.random(in: -0.5...0.5))
            }
            bNode.runAction(.repeatForever(flash))
            node.addChildNode(bNode)
        }
    }

    // MARK: - Rainbow Trail

    private static func buildRainbowTrail(node: SCNNode) {
        let colors: [String] = ["#FF0000", "#FF7F00", "#FFFF00", "#00FF00", "#0000FF", "#4B0082", "#8F00FF"]

        for (i, hex) in colors.enumerated() {
            let material = SCNMaterial()
            material.diffuse.contents = NSColor(hex: hex).withAlphaComponent(0.6)
            material.emission.contents = NSColor(hex: hex)
            material.emission.intensity = 0.7
            material.blendMode = .add

            let orb = SCNSphere(radius: 0.025)
            orb.materials = [material]
            let oNode = SCNNode(geometry: orb)

            let phase = Float(i) * Float.pi * 2 / Float(colors.count)
            let orbit = SCNAction.customAction(duration: 2.0) { n, elapsed in
                let t = Float(elapsed) / 2.0
                let a = phase + t * Float.pi * 2
                n.position = SCNVector3(
                    cos(a) * 0.35,
                    Float(i) * 0.08 + sin(t * Float.pi * 2) * 0.05 + 0.2,
                    sin(a) * 0.35
                )
            }
            oNode.runAction(.repeatForever(orbit))
            node.addChildNode(oNode)
        }
    }

    // MARK: - Generic Trail

    private static func buildGenericTrail(node: SCNNode, color: NSColor) {
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.5)
        material.emission.contents = color
        material.emission.intensity = 0.6
        material.blendMode = .add

        for i in 0..<4 {
            let particle = SCNSphere(radius: 0.025)
            particle.materials = [material]
            let pNode = SCNNode(geometry: particle)

            let phase = Float(i) * Float.pi * 0.5
            let orbit = SCNAction.customAction(duration: 2.0) { n, elapsed in
                let t = Float(elapsed) / 2.0
                let a = phase + t * Float.pi * 2
                n.position = SCNVector3(cos(a) * 0.3, 0.5 + sin(a * 2) * 0.1, sin(a) * 0.3)
            }
            pNode.runAction(.repeatForever(orbit))
            node.addChildNode(pNode)
        }
    }
}
