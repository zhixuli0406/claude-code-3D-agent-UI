import SceneKit

/// Animation that moves an agent from a spawn point to their desk with a walking cycle.
/// Used when a new agent joins the scene before they start working.
struct WalkToDeskAnimation {
    static let key = "walkToDesk"

    /// Duration of the walking leg/arm cycle
    private static let strideDuration: TimeInterval = 0.35

    /// Play a walk animation from the character's current position to the target desk position.
    /// On completion, the character snaps to the final position and calls `completion`.
    static func apply(
        to character: VoxelCharacterNode,
        from spawnPosition: SCNVector3,
        to deskPosition: SCNVector3,
        completion: (() -> Void)? = nil
    ) {
        // Calculate direction and distance
        let dx = Float(deskPosition.x - spawnPosition.x)
        let dz = Float(deskPosition.z - spawnPosition.z)
        let distance = sqrt(dx * dx + dz * dz)

        // Face the target direction
        let targetAngle = atan2(dx, dz)

        // Walk speed in units per second
        let walkSpeed: Float = 1.8
        let walkDuration = TimeInterval(distance / walkSpeed)

        // Start at spawn position
        character.position = spawnPosition
        character.eulerAngles.y = CGFloat(targetAngle)

        // Start leg/arm cycle animation
        startWalkCycle(on: character)

        // Move the character node to desk
        let moveAction = SCNAction.move(to: deskPosition, duration: walkDuration)
        moveAction.timingMode = .easeInEaseOut

        character.runAction(.sequence([
            moveAction,
            .run { _ in
                // Stop walk cycle
                stopWalkCycle(on: character)

                // Face the desk (rotate to the desk orientation)
                let faceDeskAngle = CGFloat(deskPosition.z > spawnPosition.z ? 0 : Float.pi)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.3
                character.eulerAngles.y = faceDeskAngle
                SCNTransaction.commit()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    completion?()
                }
            }
        ]), forKey: key)
    }

    /// Apply a walk cycle to an agent that faces and walks to an arbitrary target position.
    /// The agent retains its desk position reference for returning later.
    static func walkTo(
        character: VoxelCharacterNode,
        target: SCNVector3,
        completion: (() -> Void)? = nil
    ) {
        let currentPos = character.presentation.position
        let dx = Float(target.x - currentPos.x)
        let dz = Float(target.z - currentPos.z)
        let distance = sqrt(dx * dx + dz * dz)

        guard distance > 0.3 else {
            completion?()
            return
        }

        let targetAngle = atan2(dx, dz)
        let walkSpeed: Float = 1.5
        let walkDuration = TimeInterval(distance / walkSpeed)

        // Face the target
        let turnAction = SCNAction.rotateTo(x: 0, y: CGFloat(targetAngle), z: 0, duration: 0.3)
        turnAction.timingMode = .easeInEaseOut

        // Start walk cycle
        startWalkCycle(on: character)

        let moveAction = SCNAction.move(to: target, duration: walkDuration)
        moveAction.timingMode = .easeInEaseOut

        character.runAction(.sequence([
            turnAction,
            moveAction,
            .run { _ in
                stopWalkCycle(on: character)
                completion?()
            }
        ]), forKey: key)
    }

    static func remove(from character: VoxelCharacterNode) {
        character.removeAction(forKey: key)
        stopWalkCycle(on: character)
    }

    // MARK: - Walk Cycle

    private static func startWalkCycle(on character: VoxelCharacterNode) {
        let halfStride = strideDuration / 2.0

        // Leg swing: alternating forward/back
        let leftLegForward = SCNAction.rotateTo(x: -0.4, y: 0, z: 0, duration: halfStride)
        leftLegForward.timingMode = .easeInEaseOut
        let leftLegBack = SCNAction.rotateTo(x: 0.4, y: 0, z: 0, duration: halfStride)
        leftLegBack.timingMode = .easeInEaseOut
        let leftLegCycle = SCNAction.repeatForever(.sequence([leftLegForward, leftLegBack]))

        let rightLegForward = SCNAction.rotateTo(x: 0.4, y: 0, z: 0, duration: halfStride)
        rightLegForward.timingMode = .easeInEaseOut
        let rightLegBack = SCNAction.rotateTo(x: -0.4, y: 0, z: 0, duration: halfStride)
        rightLegBack.timingMode = .easeInEaseOut
        let rightLegCycle = SCNAction.repeatForever(.sequence([rightLegForward, rightLegBack]))

        // Arm swing: opposite to legs
        let leftArmForward = SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: halfStride)
        leftArmForward.timingMode = .easeInEaseOut
        let leftArmBack = SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: halfStride)
        leftArmBack.timingMode = .easeInEaseOut
        let leftArmCycle = SCNAction.repeatForever(.sequence([leftArmForward, leftArmBack]))

        let rightArmForward = SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: halfStride)
        rightArmForward.timingMode = .easeInEaseOut
        let rightArmBack = SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: halfStride)
        rightArmBack.timingMode = .easeInEaseOut
        let rightArmCycle = SCNAction.repeatForever(.sequence([rightArmForward, rightArmBack]))

        // Subtle body bob
        let bobUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: halfStride)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: halfStride)
        bobDown.timingMode = .easeInEaseOut
        let bobCycle = SCNAction.repeatForever(.sequence([bobUp, bobDown]))

        character.leftLegNode.runAction(leftLegCycle, forKey: key + "_leftLeg")
        character.rightLegNode.runAction(rightLegCycle, forKey: key + "_rightLeg")
        character.leftArmNode.runAction(leftArmCycle, forKey: key + "_leftArm")
        character.rightArmNode.runAction(rightArmCycle, forKey: key + "_rightArm")
        character.bodyNode.runAction(bobCycle, forKey: key + "_bodyBob")
    }

    private static func stopWalkCycle(on character: VoxelCharacterNode) {
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.bodyNode.removeAction(forKey: key + "_bodyBob")

        // Reset limb rotations smoothly
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        character.leftLegNode.eulerAngles = SCNVector3Zero
        character.rightLegNode.eulerAngles = SCNVector3Zero
        character.leftArmNode.eulerAngles = SCNVector3Zero
        character.rightArmNode.eulerAngles = SCNVector3Zero
        SCNTransaction.commit()
    }
}
