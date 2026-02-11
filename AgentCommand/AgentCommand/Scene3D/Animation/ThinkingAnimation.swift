import SceneKit

struct ThinkingAnimation {
    static let key = "thinkingAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Right arm raised to chin (thinking pose) with subtle chin-stroke
        let raiseArm = SCNAction.rotateTo(x: -0.8, y: 0.3, z: 0, duration: 0.8)
        raiseArm.timingMode = .easeInEaseOut
        let strokeUp = SCNAction.rotateTo(x: -0.85, y: 0.28, z: 0.05, duration: 1.2)
        strokeUp.timingMode = .easeInEaseOut
        let strokeDown = SCNAction.rotateTo(x: -0.75, y: 0.32, z: -0.05, duration: 1.2)
        strokeDown.timingMode = .easeInEaseOut

        character.rightArmNode.runAction(
            .sequence([
                raiseArm,
                .repeatForever(.sequence([strokeUp, strokeDown]))
            ]),
            forKey: key + "_rightArm"
        )

        // Left arm rests on hip (akimbo)
        let restArm = SCNAction.rotateTo(x: 0.2, y: 0, z: -0.4, duration: 0.8)
        restArm.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(restArm, forKey: key + "_leftArm")

        // Head tilts thoughtfully with occasional nod
        let tiltRight = SCNAction.rotateTo(x: 0.05, y: 0.15, z: 0.1, duration: 2.0)
        tiltRight.timingMode = .easeInEaseOut
        let tiltLeft = SCNAction.rotateTo(x: 0.05, y: -0.15, z: -0.1, duration: 2.0)
        tiltLeft.timingMode = .easeInEaseOut
        // Eureka nod
        let nodDown = SCNAction.rotateTo(x: 0.12, y: 0, z: 0, duration: 0.3)
        nodDown.timingMode = .easeIn
        let nodUp = SCNAction.rotateTo(x: -0.05, y: 0, z: 0, duration: 0.4)
        nodUp.timingMode = .easeOut
        let nodCenter = SCNAction.rotateTo(x: 0.05, y: 0, z: 0, duration: 0.3)
        nodCenter.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .repeatForever(.sequence([
                tiltRight, tiltLeft, tiltRight, tiltLeft,
                nodDown, nodUp, nodCenter, .wait(duration: 1.0)
            ])),
            forKey: key + "_head"
        )

        // Body leans and sways thoughtfully, occasional turn
        let leanBack = SCNAction.rotateTo(x: -0.08, y: 0, z: 0, duration: 1.5)
        leanBack.timingMode = .easeInEaseOut
        let leanForward = SCNAction.rotateTo(x: 0.03, y: 0, z: 0, duration: 1.5)
        leanForward.timingMode = .easeInEaseOut
        // Turn aside thoughtfully
        let turnLeft = SCNAction.rotateTo(x: 0, y: 0.2, z: 0, duration: 2.0)
        turnLeft.timingMode = .easeInEaseOut
        let turnCenter = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.5)
        turnCenter.timingMode = .easeInEaseOut

        character.bodyNode.runAction(
            .repeatForever(.sequence([
                leanBack, leanForward, leanBack, leanForward,
                turnLeft, .wait(duration: 1.0), turnCenter
            ])),
            forKey: key + "_body"
        )

        // Legs - pacing in place (shifting weight front to back)
        let leftForward = SCNAction.moveBy(x: 0, y: 0.01, z: 0.03, duration: 1.8)
        leftForward.timingMode = .easeInEaseOut
        let leftBack = SCNAction.moveBy(x: 0, y: -0.01, z: -0.03, duration: 1.8)
        leftBack.timingMode = .easeInEaseOut
        character.leftLegNode.runAction(
            .repeatForever(.sequence([leftForward, leftBack])),
            forKey: key + "_leftLeg"
        )

        let rightForward = SCNAction.moveBy(x: 0, y: -0.01, z: -0.02, duration: 1.8)
        rightForward.timingMode = .easeInEaseOut
        let rightBack = SCNAction.moveBy(x: 0, y: 0.01, z: 0.02, duration: 1.8)
        rightBack.timingMode = .easeInEaseOut
        character.rightLegNode.runAction(
            .repeatForever(.sequence([rightForward, rightBack])),
            forKey: key + "_rightLeg"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
    }
}
