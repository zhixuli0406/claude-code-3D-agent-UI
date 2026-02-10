import SceneKit

struct CompletedAnimation {
    static let key = "completedAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Celebration: both arms raise up
        let raiseLeft = SCNAction.rotateTo(x: -2.5, y: 0.3, z: 0, duration: 0.5)
        raiseLeft.timingMode = .easeOut
        let raiseRight = SCNAction.rotateTo(x: -2.5, y: -0.3, z: 0, duration: 0.5)
        raiseRight.timingMode = .easeOut

        // Wave arms back and forth
        let waveLeftA = SCNAction.rotateTo(x: -2.5, y: 0.5, z: 0, duration: 0.3)
        let waveLeftB = SCNAction.rotateTo(x: -2.5, y: 0.1, z: 0, duration: 0.3)
        let waveRightA = SCNAction.rotateTo(x: -2.5, y: -0.1, z: 0, duration: 0.3)
        let waveRightB = SCNAction.rotateTo(x: -2.5, y: -0.5, z: 0, duration: 0.3)

        let leftSequence = SCNAction.sequence([
            raiseLeft,
            .repeatForever(.sequence([waveLeftA, waveLeftB]))
        ])
        let rightSequence = SCNAction.sequence([
            raiseRight,
            .repeatForever(.sequence([waveRightA, waveRightB]))
        ])

        character.leftArmNode.runAction(leftSequence, forKey: key + "_leftArm")
        character.rightArmNode.runAction(rightSequence, forKey: key + "_rightArm")

        // Head looks up slightly
        let lookUp = SCNAction.rotateTo(x: -0.15, y: 0, z: 0, duration: 0.5)
        lookUp.timingMode = .easeInEaseOut
        character.headNode.runAction(lookUp, forKey: key + "_head")

        // Body does a small jump
        let jumpUp = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: 0.25)
        jumpUp.timingMode = .easeOut
        let jumpDown = SCNAction.moveBy(x: 0, y: -0.1, z: 0, duration: 0.25)
        jumpDown.timingMode = .easeIn
        let pause = SCNAction.wait(duration: 1.5)
        character.bodyNode.runAction(
            .repeatForever(.sequence([jumpUp, jumpDown, pause])),
            forKey: key + "_body"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
    }
}
