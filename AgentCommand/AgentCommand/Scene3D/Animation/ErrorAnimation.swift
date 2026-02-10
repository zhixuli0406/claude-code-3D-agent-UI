import SceneKit

struct ErrorAnimation {
    static let key = "errorAnimation"

    static func apply(to character: VoxelCharacterNode) {
        // Head shakes left-right (frustrated)
        let shakeLeft = SCNAction.rotateTo(x: 0, y: 0.3, z: 0, duration: 0.15)
        let shakeRight = SCNAction.rotateTo(x: 0, y: -0.3, z: 0, duration: 0.15)
        let center = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.15)
        let pause = SCNAction.wait(duration: 1.5)
        character.headNode.runAction(
            .repeatForever(.sequence([shakeLeft, shakeRight, shakeLeft, shakeRight, center, pause])),
            forKey: key + "_head"
        )

        // Arms drop / slump
        let slumpLeft = SCNAction.rotateTo(x: 0.3, y: 0, z: 0.15, duration: 0.5)
        slumpLeft.timingMode = .easeInEaseOut
        character.leftArmNode.runAction(slumpLeft, forKey: key + "_leftArm")

        let slumpRight = SCNAction.rotateTo(x: 0.3, y: 0, z: -0.15, duration: 0.5)
        slumpRight.timingMode = .easeInEaseOut
        character.rightArmNode.runAction(slumpRight, forKey: key + "_rightArm")

        // Body slumps forward
        let slumpBody = SCNAction.rotateTo(x: 0.1, y: 0, z: 0, duration: 0.5)
        slumpBody.timingMode = .easeInEaseOut
        character.bodyNode.runAction(slumpBody, forKey: key + "_body")

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
        character.statusIndicator?.removeAction(forKey: key + "_flash")
    }
}
