import SceneKit

/// Animation where an agent walks to another agent's position to "collaborate",
/// performs a brief interaction gesture, then walks back to their own desk.
struct VisitAgentAnimation {
    static let key = "visitAgent"

    /// How close the visitor stops from the target agent
    private static let stopDistance: CGFloat = 0.8

    /// Play a full visit sequence: walk to partner, gesture, walk back.
    static func apply(
        visitor: VoxelCharacterNode,
        visitorDeskPosition: SCNVector3,
        targetPosition: SCNVector3,
        completion: (() -> Void)? = nil
    ) {
        let visitorPos = visitor.presentation.position
        let dx = targetPosition.x - visitorPos.x
        let dz = targetPosition.z - visitorPos.z
        let distance = sqrt(dx * dx + dz * dz)

        guard distance > stopDistance + 0.2 else {
            // Already close enough, just gesture
            playGesture(on: visitor, facing: targetPosition) {
                completion?()
            }
            return
        }

        // Calculate a stop position slightly before the target
        let dirX = dx / distance
        let dirZ = dz / distance
        let meetPoint = SCNVector3(
            targetPosition.x - dirX * stopDistance,
            0,
            targetPosition.z - dirZ * stopDistance
        )

        // Phase 1: Walk to the target agent
        WalkToDeskAnimation.walkTo(character: visitor, target: meetPoint) {
            // Phase 2: Face the target and gesture
            let faceAngle = atan2(Float(dx), Float(dz))
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            visitor.eulerAngles.y = CGFloat(faceAngle)
            SCNTransaction.commit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                playGesture(on: visitor, facing: targetPosition) {
                    // Phase 3: Walk back to own desk
                    WalkToDeskAnimation.walkTo(character: visitor, target: visitorDeskPosition) {
                        // Face original desk orientation
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.3
                        visitor.eulerAngles.y = CGFloat(Float.pi)
                        SCNTransaction.commit()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            completion?()
                        }
                    }
                }
            }
        }
    }

    /// Play a brief discussion gesture (head nod + arm pointing)
    private static func playGesture(
        on character: VoxelCharacterNode,
        facing target: SCNVector3,
        completion: (() -> Void)? = nil
    ) {
        let gestureDuration: TimeInterval = 2.0

        // Right arm gestures (pointing and waving)
        let raiseArm = SCNAction.rotateTo(x: -1.2, y: -0.3, z: 0, duration: 0.3)
        raiseArm.timingMode = .easeOut
        let gestureA = SCNAction.rotateTo(x: -1.0, y: -0.5, z: 0.1, duration: 0.25)
        gestureA.timingMode = .easeInEaseOut
        let gestureB = SCNAction.rotateTo(x: -1.2, y: -0.1, z: -0.1, duration: 0.25)
        gestureB.timingMode = .easeInEaseOut
        let lowerArm = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
        lowerArm.timingMode = .easeInEaseOut

        character.rightArmNode.runAction(
            .sequence([raiseArm, gestureA, gestureB, gestureA, gestureB, lowerArm]),
            forKey: key + "_rightArm"
        )

        // Head nods during conversation
        let nodDown = SCNAction.rotateTo(x: 0.1, y: 0, z: 0, duration: 0.25)
        nodDown.timingMode = .easeInEaseOut
        let nodUp = SCNAction.rotateTo(x: -0.05, y: 0, z: 0, duration: 0.25)
        nodUp.timingMode = .easeInEaseOut
        let headReset = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
        headReset.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .sequence([
                nodDown, nodUp, nodDown, nodUp,
                .wait(duration: 0.3),
                headReset
            ]),
            forKey: key + "_head"
        )

        // Complete after gesture duration
        DispatchQueue.main.asyncAfter(deadline: .now() + gestureDuration) {
            completion?()
        }
    }

    static func remove(from character: VoxelCharacterNode) {
        WalkToDeskAnimation.remove(from: character)
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.headNode.removeAction(forKey: key + "_head")
    }
}
