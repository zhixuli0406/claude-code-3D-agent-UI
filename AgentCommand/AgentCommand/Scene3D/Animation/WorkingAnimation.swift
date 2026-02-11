import SceneKit

struct WorkingAnimation {
    static let key = "workingAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Typing motion - arms alternate with occasional pause to think
        let leftDown = SCNAction.rotateTo(x: 0.5, y: 0, z: 0.1, duration: 0.18)
        leftDown.timingMode = .easeInEaseOut
        let leftUp = SCNAction.rotateTo(x: 0.3, y: 0, z: 0.1, duration: 0.18)
        leftUp.timingMode = .easeInEaseOut
        // Brief pause — thinking about next line of code
        let leftPause = SCNAction.rotateTo(x: 0.15, y: 0.1, z: 0.05, duration: 0.3)
        leftPause.timingMode = .easeInEaseOut
        let leftResume = SCNAction.rotateTo(x: 0.3, y: 0, z: 0.1, duration: 0.2)
        leftResume.timingMode = .easeInEaseOut

        character.leftArmNode.runAction(
            .repeatForever(.sequence([
                leftDown, leftUp, leftDown, leftUp, leftDown, leftUp,
                leftDown, leftUp, leftDown, leftUp,
                leftPause, .wait(duration: 0.4), leftResume
            ])),
            forKey: key + "_leftArm"
        )

        let rightDown = SCNAction.rotateTo(x: 0.3, y: 0, z: -0.1, duration: 0.18)
        rightDown.timingMode = .easeInEaseOut
        let rightUp = SCNAction.rotateTo(x: 0.5, y: 0, z: -0.1, duration: 0.18)
        rightUp.timingMode = .easeInEaseOut
        let rightPause = SCNAction.rotateTo(x: 0.15, y: -0.1, z: -0.05, duration: 0.3)
        rightPause.timingMode = .easeInEaseOut
        let rightResume = SCNAction.rotateTo(x: 0.5, y: 0, z: -0.1, duration: 0.2)
        rightResume.timingMode = .easeInEaseOut

        character.rightArmNode.runAction(
            .repeatForever(.sequence([
                rightDown, rightUp, rightDown, rightUp, rightDown, rightUp,
                rightDown, rightUp, rightDown, rightUp,
                rightPause, .wait(duration: 0.4), rightResume
            ])),
            forKey: key + "_rightArm"
        )

        // Head nods subtly, occasionally leans forward to read closely
        let nodDown = SCNAction.rotateTo(x: 0.08, y: 0, z: 0, duration: 1.2)
        nodDown.timingMode = .easeInEaseOut
        let nodUp = SCNAction.rotateTo(x: -0.03, y: 0, z: 0, duration: 1.2)
        nodUp.timingMode = .easeInEaseOut
        let leanIn = SCNAction.rotateTo(x: 0.15, y: 0.05, z: 0, duration: 1.5)
        leanIn.timingMode = .easeInEaseOut
        let leanBack = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.0)
        leanBack.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .repeatForever(.sequence([
                nodDown, nodUp, nodDown, nodUp, nodDown, nodUp,
                leanIn, .wait(duration: 0.8), leanBack
            ])),
            forKey: key + "_head"
        )

        // Body micro-bob
        let bob = SCNAction.moveBy(x: 0, y: 0.01, z: 0, duration: 0.6)
        bob.timingMode = .easeInEaseOut
        let bobBack = SCNAction.moveBy(x: 0, y: -0.01, z: 0, duration: 0.6)
        bobBack.timingMode = .easeInEaseOut
        character.bodyNode.runAction(
            .repeatForever(.sequence([bob, bobBack])),
            forKey: key + "_body"
        )

        // Legs - subtle rhythmic tapping while typing
        let leftTap = SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 0.12)
        leftTap.timingMode = .easeOut
        let leftTapDown = SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 0.08)
        leftTapDown.timingMode = .easeIn
        character.leftLegNode.runAction(
            .repeatForever(.sequence([leftTap, leftTapDown, .wait(duration: 0.7)])),
            forKey: key + "_leftLeg"
        )

        // Right leg taps offset from left
        let rightTap = SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 0.12)
        rightTap.timingMode = .easeOut
        let rightTapDown = SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 0.08)
        rightTapDown.timingMode = .easeIn
        character.rightLegNode.runAction(
            .repeatForever(.sequence([.wait(duration: 0.45), rightTap, rightTapDown, .wait(duration: 0.25)])),
            forKey: key + "_rightLeg"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
    }
}
