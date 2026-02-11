import SceneKit

struct WaitingForAnswerAnimation {
    static let key = "waitingForAnswerAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Both arms slightly out, palms up gesture (offering/asking)
        let leftArmOut = SCNAction.rotateTo(x: -1.2, y: 0, z: 0.3, duration: 0.6)
        leftArmOut.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(leftArmOut, forKey: key + "_leftArm")

        let rightArmOut = SCNAction.rotateTo(x: -1.2, y: 0, z: -0.3, duration: 0.6)
        rightArmOut.timingMode = .easeInEaseOut
        character.rightArmNode.runAction(rightArmOut, forKey: key + "_rightArm")

        // Head tilted, occasionally looking around for a response
        let tiltHead = SCNAction.rotateTo(x: -0.1, y: 0, z: 0.15, duration: 0.5)
        tiltHead.timingMode = .easeInEaseOut
        let glanceLeft = SCNAction.rotateTo(x: -0.05, y: 0.2, z: 0.1, duration: 0.8)
        glanceLeft.timingMode = .easeInEaseOut
        let glanceCenter = SCNAction.rotateTo(x: -0.1, y: 0, z: 0.15, duration: 0.6)
        glanceCenter.timingMode = .easeInEaseOut
        let glanceRight = SCNAction.rotateTo(x: -0.05, y: -0.2, z: 0.1, duration: 0.8)
        glanceRight.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .sequence([
                tiltHead,
                .repeatForever(.sequence([
                    .wait(duration: 2.5),
                    glanceLeft, .wait(duration: 0.5), glanceCenter,
                    .wait(duration: 3.0),
                    glanceRight, .wait(duration: 0.5), glanceCenter
                ]))
            ]),
            forKey: key + "_head"
        )

        // Body gentle up-down bob (patient waiting)
        let bobUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.5)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 1.5)
        bobDown.timingMode = .easeInEaseOut
        character.bodyNode.runAction(
            .repeatForever(.sequence([bobUp, bobDown])),
            forKey: key + "_body"
        )

        // Legs - one foot rocks back and forth (impatient idle habit)
        let leftRock = SCNAction.moveBy(x: 0, y: 0.01, z: 0.02, duration: 1.2)
        leftRock.timingMode = .easeInEaseOut
        let leftRockBack = SCNAction.moveBy(x: 0, y: -0.01, z: -0.02, duration: 1.2)
        leftRockBack.timingMode = .easeInEaseOut
        character.leftLegNode.runAction(
            .repeatForever(.sequence([leftRock, leftRockBack])),
            forKey: key + "_leftLeg"
        )

        // Right leg stays planted
        let rightTap = SCNAction.moveBy(x: 0, y: 0.015, z: 0, duration: 0.2)
        rightTap.timingMode = .easeOut
        let rightTapDown = SCNAction.moveBy(x: 0, y: -0.015, z: 0, duration: 0.15)
        rightTapDown.timingMode = .easeIn
        character.rightLegNode.runAction(
            .repeatForever(.sequence([.wait(duration: 2.0), rightTap, rightTapDown])),
            forKey: key + "_rightLeg"
        )

        // Status indicator blue pulse
        if let indicator = character.statusIndicator,
           let geometry = indicator.geometry as? SCNSphere,
           let material = geometry.materials.first {
            let pulseUp = SCNAction.customAction(duration: 1.0) { _, elapsed in
                let t = elapsed / 1.0
                material.emission.intensity = CGFloat(0.3 + 0.5 * sin(Float(t) * .pi))
            }
            let pulseDown = SCNAction.customAction(duration: 1.0) { _, elapsed in
                let t = elapsed / 1.0
                material.emission.intensity = CGFloat(0.8 - 0.5 * sin(Float(t) * .pi))
            }
            indicator.runAction(
                .repeatForever(.sequence([pulseUp, pulseDown])),
                forKey: key + "_pulse"
            )
        }
    }

    static func remove(from character: VoxelCharacterNode) {
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
        character.statusIndicator?.removeAction(forKey: key + "_pulse")
    }
}
