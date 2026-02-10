import SceneKit

struct RoomBuilder {
    static func build(dimensions: RoomDimensions, palette: ThemeColorPalette = .commandCenter) -> SCNNode {
        let room = SCNNode()
        room.name = "room"

        let w = CGFloat(dimensions.width)
        let h = CGFloat(dimensions.height)
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

        // Back wall
        let backWall = SCNBox(width: w, height: h, length: 0.1, chamferRadius: 0)
        let wallMaterial = SCNMaterial()
        wallMaterial.diffuse.contents = NSColor(hex: palette.wallColor)
        wallMaterial.roughness.contents = 0.8
        wallMaterial.transparency = 0.9
        backWall.materials = [wallMaterial]
        let backWallNode = SCNNode(geometry: backWall)
        backWallNode.position = SCNVector3(0, Float(h) / 2.0, -2.0)
        backWallNode.name = "backWall"
        room.addChildNode(backWallNode)

        // Side walls
        let sideWall = SCNBox(width: 0.1, height: h, length: d, chamferRadius: 0)
        let sideWallMaterial = SCNMaterial()
        sideWallMaterial.diffuse.contents = NSColor(hex: palette.wallColor)
        sideWallMaterial.roughness.contents = 0.8
        sideWallMaterial.transparency = 0.7
        sideWall.materials = [sideWallMaterial]

        let leftWallNode = SCNNode(geometry: sideWall)
        leftWallNode.position = SCNVector3(-Float(w) / 2.0, Float(h) / 2.0, Float(d) / 2.0 - 2.0)
        leftWallNode.name = "leftWall"
        room.addChildNode(leftWallNode)

        let rightWallGeo = sideWall.copy() as? SCNGeometry ?? sideWall
        let rightWallNode = SCNNode(geometry: rightWallGeo)
        rightWallNode.position = SCNVector3(Float(w) / 2.0, Float(h) / 2.0, Float(d) / 2.0 - 2.0)
        rightWallNode.name = "rightWall"
        room.addChildNode(rightWallNode)

        // Ceiling accent strips
        addCeilingAccents(to: room, dimensions: dimensions, palette: palette)

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

    private static func addCeilingAccents(to room: SCNNode, dimensions: RoomDimensions, palette: ThemeColorPalette) {
        let accentColor = NSColor(hex: palette.accentColor)
        let accentMaterial = SCNMaterial()
        accentMaterial.diffuse.contents = accentColor
        accentMaterial.emission.contents = accentColor

        for xOffset: Float in [-3.0, 3.0] {
            let strip = SCNBox(width: 0.1, height: 0.05, length: CGFloat(dimensions.depth * 0.8), chamferRadius: 0)
            strip.materials = [accentMaterial]
            let stripNode = SCNNode(geometry: strip)
            stripNode.position = SCNVector3(xOffset, dimensions.height - 0.05, dimensions.depth / 2.0 - 2.0)
            room.addChildNode(stripNode)
        }
    }
}
