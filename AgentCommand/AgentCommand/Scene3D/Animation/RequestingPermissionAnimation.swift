import SceneKit

struct RequestingPermissionAnimation {
    static let key = "requestingPermissionAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Right hand raised high — "stop" / requesting gesture
        let raiseRight = SCNAction.rotateTo(x: -2.8, y: 0, z: 0.2, duration: 0.6)
        raiseRight.timingMode = .easeInEaseOut
        character.rightArmNode.runAction(raiseRight, forKey: key + "_rightArm")

        // Left arm slightly out
        let leftOut = SCNAction.rotateTo(x: -0.3, y: 0, z: -0.2, duration: 0.6)
        leftOut.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(leftOut, forKey: key + "_leftArm")

        // Body sways left-right (nervous / attention-seeking)
        let swayLeft = SCNAction.rotateTo(x: 0, y: 0.08, z: 0.06, duration: 0.8)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = SCNAction.rotateTo(x: 0, y: -0.08, z: -0.06, duration: 0.8)
        swayRight.timingMode = .easeInEaseOut
        character.bodyNode.runAction(
            .repeatForever(.sequence([swayLeft, swayRight])),
            forKey: key + "_body"
        )

        // Head looks up (asking)
        let lookUp = SCNAction.rotateTo(x: -0.2, y: 0, z: 0, duration: 0.5)
        lookUp.timingMode = .easeInEaseOut
        character.headNode.runAction(lookUp, forKey: key + "_head")

        // Status indicator pulse (orange)
        if let indicator = character.statusIndicator,
           let geometry = indicator.geometry as? SCNSphere,
           let material = geometry.materials.first {
            let pulseUp = SCNAction.customAction(duration: 0.6) { node, elapsed in
                let t = elapsed / 0.6
                material.emission.intensity = CGFloat(0.3 + 0.7 * sin(Float(t) * .pi))
            }
            let pulseDown = SCNAction.customAction(duration: 0.6) { node, elapsed in
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
        character.statusIndicator?.removeAction(forKey: key + "_pulse")
    }
}
