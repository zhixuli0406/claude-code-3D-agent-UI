import SceneKit

/// 3D grid definition where each integer maps to a color key in VoxelPalette (0 = air/empty)
struct VoxelGrid {
    /// layers[y][z][x] - y is up, z is depth, x is width
    let layers: [[[Int]]]

    var height: Int { layers.count }
    var depth: Int { layers.first?.count ?? 0 }
    var width: Int { layers.first?.first?.count ?? 0 }
}

/// Core voxel assembly engine
struct VoxelBuilder {
    static let voxelSize: CGFloat = 0.1

    /// Build a single voxel cube
    static func buildVoxel(color: NSColor) -> SCNNode {
        let box = SCNBox(
            width: voxelSize,
            height: voxelSize,
            length: voxelSize,
            chamferRadius: 0
        )
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = 0.7
        box.materials = [material]
        return SCNNode(geometry: box)
    }

    /// Build a block of voxels from a 3D grid, centered at origin
    static func buildBlock(from grid: VoxelGrid, palette: VoxelPalette) -> SCNNode {
        let parent = SCNNode()

        let offsetX = Float(grid.width) / 2.0
        let offsetZ = Float(grid.depth) / 2.0

        for (y, layer) in grid.layers.enumerated() {
            for (z, row) in layer.enumerated() {
                for (x, colorKey) in row.enumerated() {
                    guard colorKey != 0 else { continue }
                    let color = palette.color(for: colorKey)
                    let voxel = buildVoxel(color: color)
                    voxel.position = SCNVector3(
                        (Float(x) - offsetX) * Float(voxelSize),
                        Float(y) * Float(voxelSize),
                        (Float(z) - offsetZ) * Float(voxelSize)
                    )
                    parent.addChildNode(voxel)
                }
            }
        }

        // Flatten for performance (merges into single draw call)
        return parent.flattenedClone()
    }

    /// Build a block that keeps individual node structure (for animation pivot points)
    static func buildBlockUnflattened(from grid: VoxelGrid, palette: VoxelPalette) -> SCNNode {
        let parent = SCNNode()

        let offsetX = Float(grid.width) / 2.0
        let offsetZ = Float(grid.depth) / 2.0

        for (y, layer) in grid.layers.enumerated() {
            for (z, row) in layer.enumerated() {
                for (x, colorKey) in row.enumerated() {
                    guard colorKey != 0 else { continue }
                    let color = palette.color(for: colorKey)
                    let voxel = buildVoxel(color: color)
                    voxel.position = SCNVector3(
                        (Float(x) - offsetX) * Float(voxelSize),
                        Float(y) * Float(voxelSize),
                        (Float(z) - offsetZ) * Float(voxelSize)
                    )
                    parent.addChildNode(voxel)
                }
            }
        }

        return parent
    }
}
