import SceneKit

struct IdleAnimation {
    static let key = "idleAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Subtle breathing - body bobs up and down
        let breatheUp = SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 2.0)
        breatheUp.timingMode = .easeInEaseOut
        let breatheDown = SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 2.0)
        breatheDown.timingMode = .easeInEaseOut
        character.bodyNode.runAction(
            .repeatForever(.sequence([breatheUp, breatheDown])),
            forKey: key + "_breathe"
        )

        // Occasional head turn
        let wait1 = SCNAction.wait(duration: 3.0, withRange: 2.0)
        let lookLeft = SCNAction.rotateTo(x: 0, y: 0.25, z: 0, duration: 1.5)
        lookLeft.timingMode = .easeInEaseOut
        let wait2 = SCNAction.wait(duration: 2.0, withRange: 1.0)
        let lookCenter = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.0)
        lookCenter.timingMode = .easeInEaseOut
        let wait3 = SCNAction.wait(duration: 3.0, withRange: 2.0)
        let lookRight = SCNAction.rotateTo(x: 0, y: -0.25, z: 0, duration: 1.5)
        lookRight.timingMode = .easeInEaseOut
        let wait4 = SCNAction.wait(duration: 2.0, withRange: 1.0)
        let backCenter = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.0)
        backCenter.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .repeatForever(.sequence([wait1, lookLeft, wait2, lookCenter, wait3, lookRight, wait4, backCenter])),
            forKey: key + "_head"
        )

        // Arms at rest - slight sway
        let armSway1 = SCNAction.rotateTo(x: 0.05, y: 0, z: 0, duration: 2.5)
        armSway1.timingMode = .easeInEaseOut
        let armSway2 = SCNAction.rotateTo(x: -0.05, y: 0, z: 0, duration: 2.5)
        armSway2.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(
            .repeatForever(.sequence([armSway1, armSway2])),
            forKey: key + "_leftArm"
        )
        character.rightArmNode.runAction(
            .repeatForever(.sequence([armSway2, armSway1])),
            forKey: key + "_rightArm"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.bodyNode.removeAction(forKey: key + "_breathe")
        character.headNode.removeAction(forKey: key + "_head")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
    }
}
