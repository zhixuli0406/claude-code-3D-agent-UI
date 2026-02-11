import SceneKit

/// Animation played when an agent has been idle for too long
struct SleepingAnimation {
    static let key = "sleepingAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Head droops forward and sways slightly (nodding off)
        let droopDown = SCNAction.rotateTo(x: 0.4, y: 0, z: 0.05, duration: 2.0)
        droopDown.timingMode = .easeInEaseOut
        let droopSway = SCNAction.rotateTo(x: 0.35, y: 0.1, z: -0.05, duration: 3.0)
        droopSway.timingMode = .easeInEaseOut
        let droopBack = SCNAction.rotateTo(x: 0.4, y: -0.05, z: 0.03, duration: 3.0)
        droopBack.timingMode = .easeInEaseOut
        // Occasional jolt awake
        let joltUp = SCNAction.rotateTo(x: -0.1, y: 0, z: 0, duration: 0.2)
        joltUp.timingMode = .easeOut
        let lookAround = SCNAction.rotateTo(x: 0, y: 0.2, z: 0, duration: 0.5)
        lookAround.timingMode = .easeInEaseOut
        let fallBackAsleep = SCNAction.rotateTo(x: 0.4, y: 0, z: 0.05, duration: 1.5)
        fallBackAsleep.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .repeatForever(.sequence([
                droopDown, droopSway, droopBack, droopSway,
                // Jolt awake occasionally
                joltUp, lookAround, .wait(duration: 0.5), fallBackAsleep
            ])),
            forKey: key + "_head"
        )

        // Body slumps and does slow breathing
        let slump = SCNAction.rotateTo(x: 0.15, y: 0, z: 0.02, duration: 1.5)
        slump.timingMode = .easeInEaseOut
        let breatheIn = SCNAction.moveBy(x: 0, y: 0.015, z: 0, duration: 2.5)
        breatheIn.timingMode = .easeInEaseOut
        let breatheOut = SCNAction.moveBy(x: 0, y: -0.015, z: 0, duration: 2.5)
        breatheOut.timingMode = .easeInEaseOut

        character.bodyNode.runAction(
            .sequence([slump, .repeatForever(.sequence([breatheIn, breatheOut]))]),
            forKey: key + "_body"
        )

        // Arms hang loosely
        let leftHang = SCNAction.rotateTo(x: 0.15, y: 0, z: 0.1, duration: 1.5)
        leftHang.timingMode = .easeInEaseOut
        let leftSway = SCNAction.rotateTo(x: 0.2, y: 0, z: 0.15, duration: 3.0)
        leftSway.timingMode = .easeInEaseOut
        let leftSwayBack = SCNAction.rotateTo(x: 0.15, y: 0, z: 0.1, duration: 3.0)
        leftSwayBack.timingMode = .easeInEaseOut

        character.leftArmNode.runAction(
            .sequence([leftHang, .repeatForever(.sequence([leftSway, leftSwayBack]))]),
            forKey: key + "_leftArm"
        )

        let rightHang = SCNAction.rotateTo(x: 0.15, y: 0, z: -0.1, duration: 1.5)
        rightHang.timingMode = .easeInEaseOut
        let rightSway = SCNAction.rotateTo(x: 0.2, y: 0, z: -0.15, duration: 3.0)
        rightSway.timingMode = .easeInEaseOut
        let rightSwayBack = SCNAction.rotateTo(x: 0.15, y: 0, z: -0.1, duration: 3.0)
        rightSwayBack.timingMode = .easeInEaseOut

        character.rightArmNode.runAction(
            .sequence([rightHang, .repeatForever(.sequence([rightSway, rightSwayBack]))]),
            forKey: key + "_rightArm"
        )

        // Legs stay still, slight shift
        let leftLegSettle = SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 4.0)
        leftLegSettle.timingMode = .easeInEaseOut
        let leftLegBack = SCNAction.moveBy(x: -0.01, y: 0, z: 0, duration: 4.0)
        leftLegBack.timingMode = .easeInEaseOut
        character.leftLegNode.runAction(
            .repeatForever(.sequence([leftLegSettle, leftLegBack])),
            forKey: key + "_leftLeg"
        )
        character.rightLegNode.runAction(
            .repeatForever(.sequence([leftLegBack, leftLegSettle])),
            forKey: key + "_rightLeg"
        )

        // Add floating "Zzz" particles
        let zzz = buildSleepParticles()
        zzz.position = SCNVector3(0.3, 2.0, 0)
        zzz.name = "sleepZzz"
        character.addChildNode(zzz)
    }

    static func remove(from character: VoxelCharacterNode) {
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
        character.childNode(withName: "sleepZzz", recursively: false)?.removeFromParentNode()
    }

    private static func buildSleepParticles() -> SCNNode {
        let container = SCNNode()

        func spawnZ() -> SCNAction {
            return SCNAction.run { node in
                let text = SCNText(string: "z", extrusionDepth: 0.01)
                text.font = NSFont.systemFont(ofSize: 0.2, weight: .bold)
                let mat = SCNMaterial()
                mat.diffuse.contents = NSColor.white.withAlphaComponent(0.6)
                mat.emission.contents = NSColor.white.withAlphaComponent(0.3)
                mat.emission.intensity = 0.5
                text.materials = [mat]

                let zNode = SCNNode(geometry: text)
                zNode.scale = SCNVector3(0.5, 0.5, 0.5)
                zNode.position = SCNVector3(
                    Float.random(in: -0.1...0.1),
                    0,
                    Float.random(in: -0.1...0.1)
                )

                let constraint = SCNBillboardConstraint()
                constraint.freeAxes = .Y
                zNode.constraints = [constraint]

                let duration = Double.random(in: 2.0...3.0)
                let floatUp = SCNAction.moveBy(x: CGFloat(Float.random(in: -0.3...0.3)), y: 1.5, z: 0, duration: duration)
                floatUp.timingMode = .easeOut
                let scaleUp = SCNAction.scale(to: 1.2, duration: duration * 0.5)
                let fadeOut = SCNAction.fadeOut(duration: duration * 0.7)

                zNode.runAction(.sequence([
                    .group([floatUp, .sequence([scaleUp, fadeOut])]),
                    .removeFromParentNode()
                ]))

                node.addChildNode(zNode)
            }
        }

        let spawnLoop = SCNAction.repeatForever(.sequence([
            spawnZ(),
            .wait(duration: 1.5, withRange: 0.5)
        ]))
        container.runAction(spawnLoop, forKey: "sleepSpawn")

        return container
    }
}
