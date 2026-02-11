import SceneKit

struct CompletedAnimation {
    static let key = "completedAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Arms: raise up, wave, and clap
        let raiseLeft = SCNAction.rotateTo(x: -2.5, y: 0.3, z: 0, duration: 0.5)
        raiseLeft.timingMode = .easeOut
        let raiseRight = SCNAction.rotateTo(x: -2.5, y: -0.3, z: 0, duration: 0.5)
        raiseRight.timingMode = .easeOut

        // Wave arms
        let waveLeftA = SCNAction.rotateTo(x: -2.5, y: 0.5, z: 0, duration: 0.3)
        let waveLeftB = SCNAction.rotateTo(x: -2.5, y: 0.1, z: 0, duration: 0.3)
        let waveRightA = SCNAction.rotateTo(x: -2.5, y: -0.1, z: 0, duration: 0.3)
        let waveRightB = SCNAction.rotateTo(x: -2.5, y: -0.5, z: 0, duration: 0.3)

        // Clap motion — arms come together then apart
        let clapLeftIn = SCNAction.rotateTo(x: -1.5, y: -0.1, z: 0.3, duration: 0.15)
        clapLeftIn.timingMode = .easeIn
        let clapLeftOut = SCNAction.rotateTo(x: -1.5, y: 0.4, z: 0, duration: 0.15)
        clapLeftOut.timingMode = .easeOut
        let clapRightIn = SCNAction.rotateTo(x: -1.5, y: 0.1, z: -0.3, duration: 0.15)
        clapRightIn.timingMode = .easeIn
        let clapRightOut = SCNAction.rotateTo(x: -1.5, y: -0.4, z: 0, duration: 0.15)
        clapRightOut.timingMode = .easeOut

        // Back to raised after clap
        let reRaiseLeft = SCNAction.rotateTo(x: -2.5, y: 0.3, z: 0, duration: 0.3)
        reRaiseLeft.timingMode = .easeOut
        let reRaiseRight = SCNAction.rotateTo(x: -2.5, y: -0.3, z: 0, duration: 0.3)
        reRaiseRight.timingMode = .easeOut

        let leftSequence = SCNAction.sequence([
            raiseLeft,
            .repeat(.sequence([waveLeftA, waveLeftB]), count: 4),
            // Clap sequence
            clapLeftIn, clapLeftOut, clapLeftIn, clapLeftOut, clapLeftIn, clapLeftOut,
            reRaiseLeft,
            .repeatForever(.sequence([waveLeftA, waveLeftB]))
        ])
        let rightSequence = SCNAction.sequence([
            raiseRight,
            .repeat(.sequence([waveRightA, waveRightB]), count: 4),
            // Clap sequence
            clapRightIn, clapRightOut, clapRightIn, clapRightOut, clapRightIn, clapRightOut,
            reRaiseRight,
            .repeatForever(.sequence([waveRightA, waveRightB]))
        ])

        character.leftArmNode.runAction(leftSequence, forKey: key + "_leftArm")
        character.rightArmNode.runAction(rightSequence, forKey: key + "_rightArm")

        // Head looks up with happy bobbing
        let lookUp = SCNAction.rotateTo(x: -0.15, y: 0, z: 0, duration: 0.5)
        lookUp.timingMode = .easeInEaseOut
        let headBobLeft = SCNAction.rotateTo(x: -0.1, y: 0.1, z: 0.08, duration: 0.4)
        headBobLeft.timingMode = .easeInEaseOut
        let headBobRight = SCNAction.rotateTo(x: -0.1, y: -0.1, z: -0.08, duration: 0.4)
        headBobRight.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .sequence([lookUp, .repeatForever(.sequence([headBobLeft, headBobRight]))]),
            forKey: key + "_head"
        )

        // Body does a jump + occasional spin
        let jumpUp = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: 0.25)
        jumpUp.timingMode = .easeOut
        let jumpDown = SCNAction.moveBy(x: 0, y: -0.1, z: 0, duration: 0.25)
        jumpDown.timingMode = .easeIn
        let pause = SCNAction.wait(duration: 1.5)
        // Celebratory spin
        let spinJumpUp = SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.3)
        spinJumpUp.timingMode = .easeOut
        let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 0.6)
        spin.timingMode = .easeInEaseOut
        let spinJumpDown = SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.3)
        spinJumpDown.timingMode = .easeIn

        character.bodyNode.runAction(
            .repeatForever(.sequence([
                jumpUp, jumpDown, pause,
                jumpUp, jumpDown, pause,
                .group([spinJumpUp, spin]),
                spinJumpDown, pause
            ])),
            forKey: key + "_body"
        )

        // Legs - bend during jumps (crouch before, extend after)
        let legCrouch = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 0.1)
        legCrouch.timingMode = .easeIn
        let legExtend = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 0.2)
        legExtend.timingMode = .easeOut
        let legLand = SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 0.15)
        legLand.timingMode = .easeIn
        let legPause = SCNAction.wait(duration: 1.5)

        character.leftLegNode.runAction(
            .repeatForever(.sequence([legCrouch, legExtend, legLand, legPause])),
            forKey: key + "_leftLeg"
        )
        character.rightLegNode.runAction(
            .repeatForever(.sequence([legCrouch, legExtend, legLand, legPause])),
            forKey: key + "_rightLeg"
        )
    }

    static func remove(from character: VoxelCharacterNode) {
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
    }
}
