import SceneKit

struct RoomBuilder {
    static func build(dimensions: RoomDimensions, palette: ThemeColorPalette = .commandCenter) -> SCNNode {
        let room = SCNNode()
        room.name = "room"

        let w = CGFloat(dimensions.width)
        let d = CGFloat(dimensions.depth)

        // Floor
        let floor = SCNBox(width: w, height: 0.1, length: d, chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor(hex: palette.floorColor)
        floorMaterial.roughness.contents = 0.9
        floor.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.05, Float(d) / 2.0 - 2.0)
        floorNode.name = "floor"
        room.addChildNode(floorNode)

        // Floor grid lines
        addFloorGrid(to: room, dimensions: dimensions, palette: palette)

        return room
    }

    private static func addFloorGrid(to room: SCNNode, dimensions: RoomDimensions, palette: ThemeColorPalette) {
        let gridColor = NSColor(hex: palette.gridColor).withAlphaComponent(0.6)
        let gridMaterial = SCNMaterial()
        gridMaterial.diffuse.contents = gridColor
        gridMaterial.emission.contents = NSColor(hex: palette.gridColor).withAlphaComponent(0.3)

        let spacing: Float = 1.0
        let halfW = dimensions.width / 2.0
        let depth = dimensions.depth

        let xCount = Int(depth / spacing)
        for i in 0...xCount {
            let z = Float(i) * spacing - 2.0
            let line = SCNBox(width: CGFloat(dimensions.width), height: 0.005, length: 0.02, chamferRadius: 0)
            line.materials = [gridMaterial]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(0, 0.001, z)
            room.addChildNode(lineNode)
        }

        let zCount = Int(dimensions.width / spacing)
        for i in 0...zCount {
            let x = Float(i) * spacing - halfW
            let line = SCNBox(width: 0.02, height: 0.005, length: CGFloat(depth), chamferRadius: 0)
            line.materials = [gridMaterial]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(x, 0.001, depth / 2.0 - 2.0)
            room.addChildNode(lineNode)
        }
    }

}
