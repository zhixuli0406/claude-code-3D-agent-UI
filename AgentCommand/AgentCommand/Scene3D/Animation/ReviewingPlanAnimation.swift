import SceneKit

struct ReviewingPlanAnimation {
    static let key = "reviewingPlanAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Right arm held up in front — holding/reading a document
        let raiseRight = SCNAction.rotateTo(x: -1.0, y: 0.15, z: -0.1, duration: 0.6)
        raiseRight.timingMode = .easeInEaseOut
        // Slight page-turn motion
        let pageA = SCNAction.rotateTo(x: -1.05, y: 0.2, z: -0.1, duration: 1.5)
        pageA.timingMode = .easeInEaseOut
        let pageB = SCNAction.rotateTo(x: -0.95, y: 0.1, z: -0.1, duration: 1.5)
        pageB.timingMode = .easeInEaseOut

        character.rightArmNode.runAction(
            .sequence([raiseRight, .repeatForever(.sequence([pageA, pageB]))]),
            forKey: key + "_rightArm"
        )

        // Left arm supports right elbow (thoughtful reading stance)
        let leftSupport = SCNAction.rotateTo(x: -0.5, y: -0.15, z: -0.3, duration: 0.6)
        leftSupport.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(leftSupport, forKey: key + "_leftArm")

        // Head scans up and down — reading through plan lines
        let readTop = SCNAction.rotateTo(x: -0.1, y: 0.05, z: 0, duration: 1.8)
        readTop.timingMode = .easeInEaseOut
        let readMiddle = SCNAction.rotateTo(x: 0.05, y: -0.02, z: 0, duration: 1.5)
        readMiddle.timingMode = .easeInEaseOut
        let readBottom = SCNAction.rotateTo(x: 0.15, y: 0.02, z: 0, duration: 1.8)
        readBottom.timingMode = .easeInEaseOut
        let readBackUp = SCNAction.rotateTo(x: -0.05, y: 0, z: 0, duration: 1.2)
        readBackUp.timingMode = .easeInEaseOut
        // Occasional thoughtful nod (approval)
        let nodYes = SCNAction.rotateTo(x: 0.1, y: 0, z: 0, duration: 0.25)
        nodYes.timingMode = .easeIn
        let nodBack = SCNAction.rotateTo(x: -0.02, y: 0, z: 0, duration: 0.3)
        nodBack.timingMode = .easeOut
        // Head tilt — pondering a section
        let ponderTilt = SCNAction.rotateTo(x: 0.05, y: 0.1, z: 0.12, duration: 1.0)
        ponderTilt.timingMode = .easeInEaseOut
        let ponderBack = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.8)
        ponderBack.timingMode = .easeInEaseOut

        character.headNode.runAction(
            .repeatForever(.sequence([
                readTop, readMiddle, readBottom, readBackUp,
                nodYes, nodBack, .wait(duration: 0.5),
                readTop, readMiddle, readBottom, readBackUp,
                ponderTilt, .wait(duration: 1.0), ponderBack
            ])),
            forKey: key + "_head"
        )

        // Body slightly forward (leaning in to read)
        let leanIn = SCNAction.rotateTo(x: 0.06, y: 0, z: 0, duration: 0.8)
        leanIn.timingMode = .easeInEaseOut
        let leanOut = SCNAction.rotateTo(x: -0.02, y: 0, z: 0, duration: 2.0)
        leanOut.timingMode = .easeInEaseOut
        let leanBack = SCNAction.rotateTo(x: 0.06, y: 0, z: 0, duration: 2.0)
        leanBack.timingMode = .easeInEaseOut

        character.bodyNode.runAction(
            .sequence([leanIn, .repeatForever(.sequence([leanOut, leanBack]))]),
            forKey: key + "_body"
        )

        // Legs - stable stance with subtle weight shift
        let leftShift = SCNAction.moveBy(x: 0, y: 0.01, z: 0, duration: 3.5)
        leftShift.timingMode = .easeInEaseOut
        let leftShiftBack = SCNAction.moveBy(x: 0, y: -0.01, z: 0, duration: 3.5)
        leftShiftBack.timingMode = .easeInEaseOut
        character.leftLegNode.runAction(
            .repeatForever(.sequence([leftShift, leftShiftBack])),
            forKey: key + "_leftLeg"
        )

        let rightShift = SCNAction.moveBy(x: 0, y: -0.008, z: 0, duration: 3.5)
        rightShift.timingMode = .easeInEaseOut
        let rightShiftBack = SCNAction.moveBy(x: 0, y: 0.008, z: 0, duration: 3.5)
        rightShiftBack.timingMode = .easeInEaseOut
        character.rightLegNode.runAction(
            .repeatForever(.sequence([rightShift, rightShiftBack])),
            forKey: key + "_rightLeg"
        )

        // Status indicator purple pulse
        if let indicator = character.statusIndicator,
           let geometry = indicator.geometry as? SCNSphere,
           let material = geometry.materials.first {
            let pulseUp = SCNAction.customAction(duration: 1.2) { _, elapsed in
                let t = elapsed / 1.2
                material.emission.intensity = CGFloat(0.3 + 0.4 * sin(Float(t) * .pi))
            }
            let pulseDown = SCNAction.customAction(duration: 1.2) { _, elapsed in
                let t = elapsed / 1.2
                material.emission.intensity = CGFloat(0.7 - 0.4 * sin(Float(t) * .pi))
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
        character.headNode.removeAction(forKey: key + "_head")
        character.bodyNode.removeAction(forKey: key + "_body")
        character.leftLegNode.removeAction(forKey: key + "_leftLeg")
        character.rightLegNode.removeAction(forKey: key + "_rightLeg")
        character.statusIndicator?.removeAction(forKey: key + "_pulse")
    }
}
