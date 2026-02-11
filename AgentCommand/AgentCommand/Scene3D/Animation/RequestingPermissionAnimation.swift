import SceneKit

struct RequestingPermissionAnimation {
    static let key = "requestingPermissionAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Right hand raised high and waving — beckoning attention
        let raiseRight = SCNAction.rotateTo(x: -2.8, y: 0, z: 0.2, duration: 0.6)
        raiseRight.timingMode = .easeInEaseOut
        let waveA = SCNAction.rotateTo(x: -2.8, y: 0.25, z: 0.2, duration: 0.3)
        waveA.timingMode = .easeInEaseOut
        let waveB = SCNAction.rotateTo(x: -2.8, y: -0.25, z: 0.2, duration: 0.3)
        waveB.timingMode = .easeInEaseOut

        character.rightArmNode.runAction(
            .sequence([raiseRight, .repeatForever(.sequence([waveA, waveB]))]),
            forKey: key + "_rightArm"
        )

        // Left arm slightly out, gesturing
        let leftOut = SCNAction.rotateTo(x: -0.3, y: 0, z: -0.2, duration: 0.6)
        leftOut.timingMode = .easeInEaseOut
        let leftGesture = SCNAction.rotateTo(x: -0.5, y: 0.1, z: -0.3, duration: 0.8)
        leftGesture.timingMode = .easeInEaseOut
        let leftBack = SCNAction.rotateTo(x: -0.3, y: 0, z: -0.2, duration: 0.8)
        leftBack.timingMode = .easeInEaseOut

        character.leftArmNode.runAction(
            .sequence([leftOut, .repeatForever(.sequence([leftGesture, leftBack]))]),
            forKey: key + "_leftArm"
        )

        // Body sways left-right (nervous / attention-seeking)
        let swayLeft = SCNAction.rotateTo(x: 0, y: 0.08, z: 0.06, duration: 0.8)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = SCNAction.rotateTo(x: 0, y: -0.08, z: -0.06, duration: 0.8)
        swayRight.timingMode = .easeInEaseOut
        character.bodyNode.runAction(
            .repeatForever(.sequence([swayLeft, swayRight])),
            forKey: key + "_body"
        )

        // Head looks up eagerly, glancing around
        let lookUp = SCNAction.rotateTo(x: -0.2, y: 0, z: 0, duration: 0.5)
        lookUp.timingMode = .easeInEaseOut
        let glanceLeft = SCNAction.rotateTo(x: -0.15, y: 0.2, z: 0, duration: 0.6)
        glanceLeft.timingMode = .easeInEaseOut
        let glanceCenter = SCNAction.rotateTo(x: -0.2, y: 0, z: 0, duration: 0.4)
        glanceCenter.timingMode = .easeInEaseOut
        let glanceRight = SCNAction.rotateTo(x: -0.15, y: -0.2, z: 0, duration: 0.6)
        glanceRight.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .sequence([
                lookUp,
                .repeatForever(.sequence([
                    .wait(duration: 1.0), glanceLeft, glanceCenter,
                    .wait(duration: 1.0), glanceRight, glanceCenter
                ]))
            ]),
            forKey: key + "_head"
        )

        // Legs - anxious small shuffling steps
        let leftStep = SCNAction.moveBy(x: 0, y: 0.02, z: 0.01, duration: 0.2)
        leftStep.timingMode = .easeOut
        let leftStepBack = SCNAction.moveBy(x: 0, y: -0.02, z: -0.01, duration: 0.15)
        leftStepBack.timingMode = .easeIn
        character.leftLegNode.runAction(
            .repeatForever(.sequence([leftStep, leftStepBack, .wait(duration: 0.25)])),
            forKey: key + "_leftLeg"
        )

        let rightStep = SCNAction.moveBy(x: 0, y: 0.02, z: -0.01, duration: 0.2)
        rightStep.timingMode = .easeOut
        let rightStepBack = SCNAction.moveBy(x: 0, y: -0.02, z: 0.01, duration: 0.15)
        rightStepBack.timingMode = .easeIn
        character.rightLegNode.runAction(
            .repeatForever(.sequence([.wait(duration: 0.3), rightStep, rightStepBack, .wait(duration: 0.1)])),
            forKey: key + "_rightLeg"
        )

        // Status indicator pulse (orange)
        if let indicator = character.statusIndicator,
           let geometry = indicator.geometry as? SCNSphere,
           let material = geometry.materials.first {
            let pulseUp = SCNAction.customAction(duration: 0.6) { _, elapsed in
                let t = elapsed / 0.6
                material.emission.intensity = CGFloat(0.3 + 0.7 * sin(Float(t) * .pi))
            }
            let pulseDown = SCNAction.customAction(duration: 0.6) { _, elapsed in
                let t = elapsed / 0.6
                material.emission.intensity = CGFloat(1.0 - 0.7 * sin(Float(t) * .pi))
            }
            indicator.runAction(
                .repeatForever(.sequence([pulseUp, pulseDown])),
                forKey: key + "_pulse"
            )
        }
    }

    static func remove(from character: VoxelCharacterNode) {
        character.rightArmNode.removeAction(forKey: key + "_rightArm")
        character.leftArmNode.removeAction(forKey: key + "_leftArm")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.headNode.removeAction(forKey: key + "_head")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
        character.statusIndicator?.removeAction(forKey: key + "_pulse")
    }
}
