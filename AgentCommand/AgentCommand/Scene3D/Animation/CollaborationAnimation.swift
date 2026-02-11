import SceneKit

/// Animation when agents are working together (commander + sub-agents both working)
struct CollaborationAnimation {
    static let key = "collabAnimation"

    /// Apply collaboration gesture overlay - agents occasionally turn and gesture to each other
    static func applyGesture(to character: VoxelCharacterNode, faceDirection: Float) {
        // Briefly turn toward partner, gesture, then turn back
        let turnToPartner = SCNAction.rotateTo(x: 0, y: CGFloat(faceDirection), z: 0, duration: 0.5)
        turnToPartner.timingMode = .easeInEaseOut
        let turnBack = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.5)
        turnBack.timingMode = .easeInEaseOut

        // Right arm points/gestures
        let raiseArm = SCNAction.rotateTo(x: -1.2, y: -0.3, z: 0, duration: 0.3)
        raiseArm.timingMode = .easeOut
        let gestureA = SCNAction.rotateTo(x: -1.0, y: -0.5, z: 0.1, duration: 0.3)
        gestureA.timingMode = .easeInEaseOut
        let gestureB = SCNAction.rotateTo(x: -1.2, y: -0.1, z: -0.1, duration: 0.3)
        gestureB.timingMode = .easeInEaseOut
        let lowerArm = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4)
        lowerArm.timingMode = .easeInEaseOut

        // Head nods during gesture
        let headNodDown = SCNAction.rotateTo(x: 0.1, y: CGFloat(faceDirection * 0.5), z: 0, duration: 0.3)
        headNodDown.timingMode = .easeInEaseOut
        let headNodUp = SCNAction.rotateTo(x: -0.05, y: CGFloat(faceDirection * 0.5), z: 0, duration: 0.3)
        headNodUp.timingMode = .easeInEaseOut
        let headReset = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4)
        headReset.timingMode = .easeInEaseOut

        // Combined sequence with long wait between gestures
        let waitBetween = SCNAction.wait(duration: 8.0, withRange: 4.0)

        character.headNode.runAction(
            .repeatForever(.sequence([
                waitBetween,
                turnToPartner,
                headNodDown, headNodUp, headNodDown, headNodUp,
                .wait(duration: 0.3),
                headReset,
                turnBack
            ])),
            forKey: key + "_head"
        )

        character.rightArmNode.runAction(
            .repeatForever(.sequence([
                waitBetween,
                raiseArm, gestureA, gestureB, gestureA,
                lowerArm,
                .wait(duration: 1.5)
            ])),
            forKey: key + "_rightArm"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.headNode.removeAction(forKey: key + "_head")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
    }
}
