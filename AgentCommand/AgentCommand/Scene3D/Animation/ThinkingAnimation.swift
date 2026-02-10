import SceneKit

struct ThinkingAnimation {
    static let key = "thinkingAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // One arm raised to chin (thinking pose)
        let raiseArm = SCNAction.rotateTo(x: -0.8, y: 0.3, z: 0, duration: 0.8)
        raiseArm.timingMode = .easeInEaseOut
        character.rightArmNode.runAction(raiseArm, forKey: key + "_rightArmRaise")

        // The other arm at rest
        let restArm = SCNAction.rotateTo(x: 0.1, y: 0, z: 0.1, duration: 0.8)
        restArm.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(restArm, forKey: key + "_leftArm")

        // Head tilts slightly
        let tiltRight = SCNAction.rotateTo(x: 0.05, y: 0.15, z: 0.1, duration: 2.0)
        tiltRight.timingMode = .easeInEaseOut
        let tiltLeft = SCNAction.rotateTo(x: 0.05, y: -0.15, z: -0.1, duration: 2.0)
        tiltLeft.timingMode = .easeInEaseOut
        character.headNode.runAction(
            .repeatForever(.sequence([tiltRight, tiltLeft])),
            forKey: key + "_head"
        )

        // Body leans back slightly
        let leanBack = SCNAction.rotateTo(x: -0.08, y: 0, z: 0, duration: 1.5)
        leanBack.timingMode = .easeInEaseOut
        let leanForward = SCNAction.rotateTo(x: 0.03, y: 0, z: 0, duration: 1.5)
        leanForward.timingMode = .easeInEaseOut
        character.bodyNode.runAction(
            .repeatForever(.sequence([leanBack, leanForward])),
            forKey: key + "_body"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.rightArmNode.removeAction(forKey: key + "_rightArmRaise")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
    }
}
