import SceneKit

/// One-shot waving animation when a new agent joins the scene
struct WavingAnimation {
    static let key = "wavingAnimation"

    /// Apply a waving greeting animation (plays once then transitions to idle)
    static func apply(to character: VoxelCharacterNode, completion: (() -> Void)? = nil) {
        // Right arm waves enthusiastically
        let raiseArm = SCNAction.rotateTo(x: -2.5, y: -0.2, z: 0, duration: 0.4)
        raiseArm.timingMode = .easeOut
        let waveA = SCNAction.rotateTo(x: -2.5, y: -0.5, z: 0, duration: 0.25)
        waveA.timingMode = .easeInEaseOut
        let waveB = SCNAction.rotateTo(x: -2.5, y: 0.1, z: 0, duration: 0.25)
        waveB.timingMode = .easeInEaseOut
        let lowerArm = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.5)
        lowerArm.timingMode = .easeInEaseOut

        let waveSequence = SCNAction.sequence([
            raiseArm,
            .repeat(.sequence([waveA, waveB]), count: 4),
            lowerArm
        ])

        character.rightArmNode.runAction(waveSequence, forKey: key + "_rightArm")

        // Left arm stays at side with slight movement
        let leftSway = SCNAction.rotateTo(x: 0.1, y: 0, z: 0.1, duration: 0.5)
        leftSway.timingMode = .easeInEaseOut
        let leftBack = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.5)
        leftBack.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(
            .sequence([leftSway, leftBack, leftSway, leftBack]),
            forKey: key + "_leftArm"
        )

        // Head looks toward camera and nods
        let lookForward = SCNAction.rotateTo(x: -0.1, y: 0, z: 0, duration: 0.3)
        lookForward.timingMode = .easeOut
        let nodDown = SCNAction.rotateTo(x: 0.05, y: 0, z: 0, duration: 0.3)
        nodDown.timingMode = .easeInEaseOut
        let nodUp = SCNAction.rotateTo(x: -0.1, y: 0, z: 0, duration: 0.3)
        nodUp.timingMode = .easeInEaseOut
        let headReset = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4)
        headReset.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .sequence([lookForward, .repeat(.sequence([nodDown, nodUp]), count: 2), headReset]),
            forKey: key + "_head"
        )

        // Body does a slight bounce
        let bounceUp = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 0.2)
        bounceUp.timingMode = .easeOut
        let bounceDown = SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 0.2)
        bounceDown.timingMode = .easeIn

        character.bodyNode.runAction(
            .sequence([
                .repeat(.sequence([bounceUp, bounceDown]), count: 3),
                .run { _ in completion?() }
            ]),
            forKey: key + "_body"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
    }
}
