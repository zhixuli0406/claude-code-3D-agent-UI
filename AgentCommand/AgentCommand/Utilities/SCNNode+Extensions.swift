import SceneKit

extension SCNNode {
    /// Walk up the node hierarchy to find a VoxelCharacterNode ancestor
    func findParentVoxelCharacter() -> VoxelCharacterNode? {
        if let character = self as? VoxelCharacterNode {
            return character
        }
        return parent?.findParentVoxelCharacter()
    }

    /// Apply a material with a single color to all geometry
    func applyColor(_ color: NSColor) {
        guard let geometry = self.geometry else { return }
        let material = SCNMaterial()
        material.diffuse.contents = color
        geometry.materials = [material]
    }
}
