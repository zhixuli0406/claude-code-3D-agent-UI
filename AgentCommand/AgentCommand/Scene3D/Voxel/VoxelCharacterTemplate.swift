import Foundation

/// Provides predefined 3D voxel grids for character body parts
/// Color keys: 0=air, 1=skin, 2=shirt, 3=pants, 4=hair, 5=eye_white, 6=eye_pupil, 7=mouth, 8=shoes, 9=accessory
struct VoxelCharacterTemplate {

    // MARK: - Head (6w x 6h x 6d)

    static func head(hairStyle: HairStyle) -> VoxelGrid {
        var layers: [[[Int]]] = []

        // Layer 0 (bottom - neck/chin)
        layers.append([
            [0,0,0,0,0,0],
            [0,1,1,1,1,0],
            [0,1,1,1,1,0],
            [0,1,1,1,1,0],
            [0,1,1,1,1,0],
            [0,0,0,0,0,0],
        ])

        // Layer 1 (mouth level)
        layers.append([
            [0,1,1,1,1,0],
            [1,1,1,1,1,1],
            [1,1,7,7,1,1],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [0,1,1,1,1,0],
        ])

        // Layer 2 (nose level)
        layers.append([
            [0,1,1,1,1,0],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [0,1,1,1,1,0],
        ])

        // Layer 3 (eye level)
        layers.append([
            [0,1,1,1,1,0],
            [1,5,6,1,5,6],
            [1,5,6,1,5,6],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [0,1,1,1,1,0],
        ])

        // Layer 4 (forehead)
        layers.append([
            [0,1,1,1,1,0],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [1,1,1,1,1,1],
            [0,1,1,1,1,0],
        ])

        // Layer 5 (top of head / hair base)
        let topLayer = hairTopLayer(hairStyle)
        layers.append(topLayer)

        // Add extra hair layers based on style
        let extraHairLayers = hairExtraLayers(hairStyle)
        layers.append(contentsOf: extraHairLayers)

        return VoxelGrid(layers: layers)
    }

    private static func hairTopLayer(_ style: HairStyle) -> [[Int]] {
        switch style {
        case .bald:
            return [
                [0,1,1,1,1,0],
                [1,1,1,1,1,1],
                [1,1,1,1,1,1],
                [1,1,1,1,1,1],
                [1,1,1,1,1,1],
                [0,1,1,1,1,0],
            ]
        case .short, .medium, .long, .mohawk:
            return [
                [0,4,4,4,4,0],
                [4,4,4,4,4,4],
                [4,4,4,4,4,4],
                [4,4,4,4,4,4],
                [4,4,4,4,4,4],
                [0,4,4,4,4,0],
            ]
        }
    }

    private static func hairExtraLayers(_ style: HairStyle) -> [[[Int]]] {
        switch style {
        case .bald:
            return []
        case .short:
            return [[
                [0,0,4,4,0,0],
                [0,4,4,4,4,0],
                [0,4,4,4,4,0],
                [0,4,4,4,4,0],
                [0,4,4,4,4,0],
                [0,0,4,4,0,0],
            ]]
        case .medium:
            return [
                [
                    [0,4,4,4,4,0],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [0,4,4,4,4,0],
                ],
                [
                    [0,0,4,4,0,0],
                    [0,4,4,4,4,0],
                    [0,4,4,4,4,0],
                    [0,4,4,4,4,0],
                    [0,4,4,4,4,0],
                    [0,0,4,4,0,0],
                ]
            ]
        case .long:
            return [
                [
                    [0,4,4,4,4,0],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [0,4,4,4,4,0],
                ],
                [
                    [0,4,4,4,4,0],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [4,4,4,4,4,4],
                    [0,4,4,4,4,0],
                ],
                [
                    [0,0,4,4,0,0],
                    [0,4,4,4,4,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,4,4,4,4,0],
                    [0,0,4,4,0,0],
                ]
            ]
        case .mohawk:
            return [
                [
                    [0,0,0,0,0,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,0,0,0,0,0],
                ],
                [
                    [0,0,0,0,0,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,0,0,0,0,0],
                ],
                [
                    [0,0,0,0,0,0],
                    [0,0,0,0,0,0],
                    [0,0,4,4,0,0],
                    [0,0,4,4,0,0],
                    [0,0,0,0,0,0],
                    [0,0,0,0,0,0],
                ]
            ]
        }
    }

    // MARK: - Torso (6w x 8h x 4d)

    static func torso() -> VoxelGrid {
        var layers: [[[Int]]] = []

        // Layer 0-1 (belt area)
        for _ in 0..<2 {
            layers.append([
                [0,2,2,2,2,0],
                [2,2,2,2,2,2],
                [2,2,2,2,2,2],
                [0,2,2,2,2,0],
            ])
        }

        // Layer 2-5 (main torso)
        for _ in 0..<4 {
            layers.append([
                [0,2,2,2,2,0],
                [2,2,2,2,2,2],
                [2,2,2,2,2,2],
                [0,2,2,2,2,0],
            ])
        }

        // Layer 6-7 (shoulder area - wider)
        for _ in 0..<2 {
            layers.append([
                [2,2,2,2,2,2],
                [2,2,2,2,2,2],
                [2,2,2,2,2,2],
                [2,2,2,2,2,2],
            ])
        }

        return VoxelGrid(layers: layers)
    }

    // MARK: - Arm (2w x 8h x 2d)

    static func arm() -> VoxelGrid {
        var layers: [[[Int]]] = []

        // Layer 0-1 (hand - skin color)
        for _ in 0..<2 {
            layers.append([
                [1,1],
                [1,1],
            ])
        }

        // Layer 2-7 (arm - shirt color)
        for _ in 0..<6 {
            layers.append([
                [2,2],
                [2,2],
            ])
        }

        return VoxelGrid(layers: layers)
    }

    // MARK: - Leg (2w x 6h x 2d)

    static func leg() -> VoxelGrid {
        var layers: [[[Int]]] = []

        // Layer 0-1 (foot - shoes)
        for _ in 0..<2 {
            layers.append([
                [8,8],
                [8,8],
            ])
        }

        // Layer 2-5 (leg - pants)
        for _ in 0..<4 {
            layers.append([
                [3,3],
                [3,3],
            ])
        }

        return VoxelGrid(layers: layers)
    }
}
