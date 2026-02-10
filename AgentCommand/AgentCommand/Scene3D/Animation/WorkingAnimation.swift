import SceneKit

struct WorkingAnimation {
    static let key = "workingAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Typing motion - arms alternate
        let leftDown = SCNAction.rotateTo(x: 0.5, y: 0, z: 0.1, duration: 0.18)
        leftDown.timingMode = .easeInEaseOut
        let leftUp = SCNAction.rotateTo(x: 0.3, y: 0, z: 0.1, duration: 0.18)
        leftUp.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(
            .repeatForever(.sequence([leftDown, leftUp])),
            forKey: key + "_leftArm"
        )

        let rightDown = SCNAction.rotateTo(x: 0.3, y: 0, z: -0.1, duration: 0.18)
        rightDown.timingMode = .easeInEaseOut
        let rightUp = SCNAction.rotateTo(x: 0.5, y: 0, z: -0.1, duration: 0.18)
        rightUp.timingMode = .easeInEaseOut
        character.rightArmNode.runAction(
            .repeatForever(.sequence([rightDown, rightUp])),
            forKey: key + "_rightArm"
        )

        // Head nods subtly while typing
        let nodDown = SCNAction.rotateTo(x: 0.08, y: 0, z: 0, duration: 1.2)
        nodDown.timingMode = .easeInEaseOut
        let nodUp = SCNAction.rotateTo(x: -0.03, y: 0, z: 0, duration: 1.2)
        nodUp.timingMode = .easeInEaseOut
        character.headNode.runAction(
            .repeatForever(.sequence([nodDown, nodUp])),
            forKey: key + "_head"
        )

        // Body stays still but has a micro-bob
        let bob = SCNAction.moveBy(x: 0, y: 0.01, z: 0, duration: 0.6)
        bob.timingMode = .easeInEaseOut
        let bobBack = SCNAction.moveBy(x: 0, y: -0.01, z: 0, duration: 0.6)
        bobBack.timingMode = .easeInEaseOut
        character.bodyNode.runAction(
            .repeatForever(.sequence([bob, bobBack])),
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
