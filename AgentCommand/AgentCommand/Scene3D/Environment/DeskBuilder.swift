import SceneKit

struct DeskBuilder {
    static func build(size: DeskSize, palette: ThemeColorPalette = .commandCenter) -> SCNNode {
        let desk = SCNNode()
        desk.name = "desk_\(size.rawValue)"

        let w = CGFloat(size.width)
        let d = CGFloat(size.depth)
        let deskHeight: CGFloat = 0.75
        let topThickness: CGFloat = 0.05
        let legRadius: CGFloat = 0.04
        let legHeight = deskHeight - topThickness

        // Desk surface
        let surface = SCNBox(width: w, height: topThickness, length: d, chamferRadius: 0.01)
        let surfaceMaterial = SCNMaterial()
        surfaceMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor)
        surfaceMaterial.metalness.contents = 0.3
        surfaceMaterial.roughness.contents = 0.6
        surface.materials = [surfaceMaterial]
        let surfaceNode = SCNNode(geometry: surface)
        surfaceNode.position = SCNVector3(0, Float(deskHeight), 0)
        desk.addChildNode(surfaceNode)

        // Desk legs
        let legMaterial = SCNMaterial()
        legMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        legMaterial.metalness.contents = 0.5

        let legPositions: [(Float, Float)] = [
            (-Float(w) / 2.0 + 0.08, -Float(d) / 2.0 + 0.08),
            (Float(w) / 2.0 - 0.08, -Float(d) / 2.0 + 0.08),
            (-Float(w) / 2.0 + 0.08, Float(d) / 2.0 - 0.08),
            (Float(w) / 2.0 - 0.08, Float(d) / 2.0 - 0.08)
        ]

        for (lx, lz) in legPositions {
            let leg = SCNCylinder(radius: legRadius, height: legHeight)
            leg.materials = [legMaterial]
            let legNode = SCNNode(geometry: leg)
            legNode.position = SCNVector3(lx, Float(legHeight) / 2.0, lz)
            desk.addChildNode(legNode)
        }

        // Keyboard area
        let keyboard = SCNBox(width: w * 0.5, height: 0.02, length: d * 0.25, chamferRadius: 0.005)
        let kbMaterial = SCNMaterial()
        kbMaterial.diffuse.contents = NSColor(hex: palette.floorColor)
        keyboard.materials = [kbMaterial]
        let kbNode = SCNNode(geometry: keyboard)
        kbNode.position = SCNVector3(0, Float(deskHeight) + Float(topThickness) / 2.0 + 0.01, Float(d) * 0.15)
        desk.addChildNode(kbNode)

        return desk
    }

    static func buildChair(palette: ThemeColorPalette = .commandCenter) -> SCNNode {
        let chair = SCNNode()
        chair.name = "chair"

        let seatMaterial = SCNMaterial()
        seatMaterial.diffuse.contents = NSColor(hex: palette.accentColor).withAlphaComponent(0.7)
        seatMaterial.roughness.contents = 0.8

        let seat = SCNBox(width: 0.5, height: 0.05, length: 0.5, chamferRadius: 0)
        seat.materials = [seatMaterial]
        let seatNode = SCNNode(geometry: seat)
        seatNode.position = SCNVector3(0, 0.45, 0)
        chair.addChildNode(seatNode)

        let backrest = SCNBox(width: 0.5, height: 0.5, length: 0.05, chamferRadius: 0)
        backrest.materials = [seatMaterial]
        let backrestNode = SCNNode(geometry: backrest)
        backrestNode.position = SCNVector3(0, 0.7, -0.225)
        chair.addChildNode(backrestNode)

        let legMaterial = SCNMaterial()
        legMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        legMaterial.metalness.contents = 0.7
        let pedestal = SCNCylinder(radius: 0.04, height: 0.45)
        pedestal.materials = [legMaterial]
        let pedestalNode = SCNNode(geometry: pedestal)
        pedestalNode.position = SCNVector3(0, 0.225, 0)
        chair.addChildNode(pedestalNode)

        let basePart = SCNBox(width: 0.4, height: 0.03, length: 0.06, chamferRadius: 0)
        basePart.materials = [legMaterial]
        let base1 = SCNNode(geometry: basePart)
        let base2 = SCNNode(geometry: basePart)
        base2.eulerAngles.y = .pi / 2
        chair.addChildNode(base1)
        chair.addChildNode(base2)

        return chair
    }
}
