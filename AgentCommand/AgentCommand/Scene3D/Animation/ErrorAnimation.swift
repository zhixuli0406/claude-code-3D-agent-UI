import SceneKit

struct ErrorAnimation {
    static let key = "errorAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Head shakes left-right (frustrated) with occasional face-palm look down
        let shakeLeft = SCNAction.rotateTo(x: 0, y: 0.3, z: 0, duration: 0.15)
        let shakeRight = SCNAction.rotateTo(x: 0, y: -0.3, z: 0, duration: 0.15)
        let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.15)
        let pause = SCNAction.wait(duration: 1.5)
        // Face-palm: look down in despair
        let lookDown = SCNAction.rotateTo(x: 0.25, y: 0, z: 0, duration: 0.5)
        lookDown.timingMode = .easeInEaseOut
        let stayDown = SCNAction.wait(duration: 1.0)
        let lookBackUp = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.5)
        lookBackUp.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .repeatForever(.sequence([
                shakeLeft, shakeRight, shakeLeft, shakeRight, center, pause,
                lookDown, stayDown, lookBackUp, pause
            ])),
            forKey: key + "_head"
        )

        // Arms: slump, then occasionally raise hands to head (frustrated grab)
        let slumpLeft = SCNAction.rotateTo(x: 0.3, y: 0, z: 0.15, duration: 0.5)
        slumpLeft.timingMode = .easeInEaseOut
        let slumpRight = SCNAction.rotateTo(x: 0.3, y: 0, z: -0.15, duration: 0.5)
        slumpRight.timingMode = .easeInEaseOut
        // Grab head in frustration
        let grabLeft = SCNAction.rotateTo(x: -1.8, y: 0.3, z: 0.2, duration: 0.4)
        grabLeft.timingMode = .easeOut
        let grabRight = SCNAction.rotateTo(x: -1.8, y: -0.3, z: -0.2, duration: 0.4)
        grabRight.timingMode = .easeOut
        let holdGrab = SCNAction.wait(duration: 1.5)
        let releaseLeft = SCNAction.rotateTo(x: 0.3, y: 0, z: 0.15, duration: 0.6)
        releaseLeft.timingMode = .easeInEaseOut
        let releaseRight = SCNAction.rotateTo(x: 0.3, y: 0, z: -0.15, duration: 0.6)
        releaseRight.timingMode = .easeInEaseOut

        character.leftArmNode.runAction(
            .repeatForever(.sequence([
                slumpLeft, .wait(duration: 3.0),
                grabLeft, holdGrab, releaseLeft
            ])),
            forKey: key + "_leftArm"
        )
        character.rightArmNode.runAction(
            .repeatForever(.sequence([
                slumpRight, .wait(duration: 3.0),
                grabRight, holdGrab, releaseRight
            ])),
            forKey: key + "_rightArm"
        )

        // Body slumps forward with frustrated rocking
        let slumpBody = SCNAction.rotateTo(x: 0.1, y: 0, z: 0, duration: 0.5)
        slumpBody.timingMode = .easeInEaseOut
        let rockForward = SCNAction.rotateTo(x: 0.15, y: 0, z: 0, duration: 1.0)
        rockForward.timingMode = .easeInEaseOut
        let rockBack = SCNAction.rotateTo(x: 0.05, y: 0, z: 0, duration: 1.0)
        rockBack.timingMode = .easeInEaseOut

        character.bodyNode.runAction(
            .sequence([slumpBody, .repeatForever(.sequence([rockForward, rockBack]))]),
            forKey: key + "_body"
        )

        // Legs - stomp foot in frustration
        let leftStomp = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 0.15)
        leftStomp.timingMode = .easeOut
        let leftStompDown = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: 0.08)
        leftStompDown.timingMode = .easeIn
        character.leftLegNode.runAction(
            .repeatForever(.sequence([
                .wait(duration: 3.5),
                leftStomp, leftStompDown,
                .wait(duration: 0.2),
                leftStomp, leftStompDown
            ])),
            forKey: key + "_leftLeg"
        )

        // Right leg stays mostly still, slight nervous shift
        let rightShift = SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 2.0)
        rightShift.timingMode = .easeInEaseOut
        let rightShiftBack = SCNAction.moveBy(x: -0.01, y: 0, z: 0, duration: 2.0)
        rightShiftBack.timingMode = .easeInEaseOut
        character.rightLegNode.runAction(
            .repeatForever(.sequence([rightShift, rightShiftBack])),
            forKey: key + "_rightLeg"
        )

        // Status indicator flashes red
        flashStatusIndicator(on: character)
    }

    private static func flashStatusIndicator(on character: VoxelCharacterNode) {
        guard let indicator = character.statusIndicator,
              let geometry = indicator.geometry as? SCNSphere,
              let material = geometry.materials.first else { return }

        let flashOn = SCNAction.run { _ in
            material.emission.intensity = 1.0
        }
        let flashOff = SCNAction.run { _ in
            material.emission.intensity = 0.2
        }
        let wait = SCNAction.wait(duration: 0.3)
        indicator.runAction(
            .repeatForever(.sequence([flashOn, wait, flashOff, wait])),
            forKey: key + "_flash"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.headNode.removeAction(forKey: key + "_head")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
        character.statusIndicator?.removeAction(forKey: key + "_flash")
    }
}
