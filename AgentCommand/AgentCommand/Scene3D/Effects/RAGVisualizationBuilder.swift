import SceneKit

// MARK: - H1: RAG Knowledge Graph Visualization

struct RAGVisualizationBuilder {

    // MARK: - Knowledge Graph

    static func buildKnowledgeGraph(documents: [RAGDocument], relationships: [RAGRelationship]) -> SCNNode {
        let container = SCNNode()
        container.name = "ragKnowledgeGraph"

        let docsToShow = Array(documents.prefix(30))
        guard !docsToShow.isEmpty else { return container }

        // Calculate positions in a spherical layout
        var positions: [String: SCNVector3] = [:]
        let radius: Float = 4.0

        for (i, doc) in docsToShow.enumerated() {
            let angle = Float(i) / Float(docsToShow.count) * Float.pi * 2
            let yOffset = Float(i % 3) * 0.6 - 0.6
            let pos = SCNVector3(
                sin(angle) * radius,
                yOffset,
                -cos(angle) * radius
            )
            positions[doc.id] = pos

            let docNode = buildDocumentNode(doc: doc, index: i, total: docsToShow.count)
            docNode.position = pos
            container.addChildNode(docNode)
        }

        // Draw relationship lines
        for rel in relationships {
            guard let fromPos = positions[rel.sourceId],
                  let toPos = positions[rel.targetId] else { continue }

            let lineNode = buildRelationshipLine(from: fromPos, to: toPos, type: rel.type)
            container.addChildNode(lineNode)
        }

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 60.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    // MARK: - Document Node

    static func buildDocumentNode(doc: RAGDocument, index: Int, total: Int) -> SCNNode {
        let container = SCNNode()
        container.name = "ragDoc_\(doc.id)"

        // Billboard constraint
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        container.constraints = [billboard]

        let nodeColor = NSColor(hex: doc.fileType.colorHex)

        // Document icon (box representing a file)
        let sizeScale: CGFloat = min(0.3, max(0.12, CGFloat(doc.lineCount) / 2000.0 * 0.3))
        let box = SCNBox(width: sizeScale, height: sizeScale * 1.3, length: sizeScale * 0.15, chamferRadius: 0.01)
        let boxMat = SCNMaterial()
        boxMat.diffuse.contents = nodeColor.withAlphaComponent(0.8)
        boxMat.emission.contents = nodeColor
        boxMat.emission.intensity = 0.5
        box.materials = [boxMat]
        let boxNode = SCNNode(geometry: box)
        container.addChildNode(boxNode)

        // Glow sphere behind the box
        let glow = SCNSphere(radius: sizeScale * 0.8)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = nodeColor.withAlphaComponent(0.1)
        glowMat.emission.contents = nodeColor
        glowMat.emission.intensity = 0.3
        glowMat.isDoubleSided = true
        glow.materials = [glowMat]
        let glowNode = SCNNode(geometry: glow)
        glowNode.position = SCNVector3(0, 0, -0.05)
        container.addChildNode(glowNode)

        // File name label
        let displayName = String(doc.fileName.prefix(25))
        let nameText = SCNText(string: displayName, extrusionDepth: 0.003)
        nameText.font = NSFont(name: "Menlo-Bold", size: 0.07) ?? NSFont.monospacedSystemFont(ofSize: 0.07, weight: .bold)
        nameText.flatness = 0.3
        let nameMat = SCNMaterial()
        nameMat.diffuse.contents = NSColor.white
        nameMat.emission.contents = NSColor.white
        nameMat.emission.intensity = 0.3
        nameText.materials = [nameMat]
        let nameNode = SCNNode(geometry: nameText)
        nameNode.position = SCNVector3(-0.15, Float(sizeScale * 1.3 / 2) + 0.05, 0.01)
        nameNode.scale = SCNVector3(0.5, 0.5, 0.5)
        container.addChildNode(nameNode)

        // File type badge
        let badgeText = SCNText(string: doc.fileType.displayName, extrusionDepth: 0.002)
        badgeText.font = NSFont(name: "Menlo", size: 0.05) ?? NSFont.monospacedSystemFont(ofSize: 0.05, weight: .regular)
        badgeText.flatness = 0.4
        let badgeMat = SCNMaterial()
        badgeMat.diffuse.contents = nodeColor
        badgeMat.emission.contents = nodeColor
        badgeMat.emission.intensity = 0.4
        badgeText.materials = [badgeMat]
        let badgeNode = SCNNode(geometry: badgeText)
        badgeNode.position = SCNVector3(-0.1, -Float(sizeScale * 1.3 / 2) - 0.08, 0.01)
        badgeNode.scale = SCNVector3(0.4, 0.4, 0.4)
        container.addChildNode(badgeNode)

        // Line count label
        let lineStr = "\(doc.lineCount) lines"
        let lineText = SCNText(string: lineStr, extrusionDepth: 0.002)
        lineText.font = NSFont(name: "Menlo", size: 0.04) ?? NSFont.monospacedSystemFont(ofSize: 0.04, weight: .regular)
        lineText.flatness = 0.4
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = NSColor(hex: "#8B949E")
        lineText.materials = [lineMat]
        let lineNode = SCNNode(geometry: lineText)
        lineNode.position = SCNVector3(-0.08, -Float(sizeScale * 1.3 / 2) - 0.15, 0.01)
        lineNode.scale = SCNVector3(0.35, 0.35, 0.35)
        container.addChildNode(lineNode)

        // Floating bob animation (offset by index for organic feel)
        let bobDuration = 2.5 + Double(index % 5) * 0.3
        let bobUp = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        // Glow pulse
        let pulseUp = SCNAction.customAction(duration: 1.5) { node, elapsed in
            let t = Float(elapsed) / 1.5
            let intensity = 0.3 + 0.2 * sin(t * Float.pi)
            node.geometry?.materials.first?.emission.intensity = CGFloat(intensity)
        }
        glowNode.runAction(.repeatForever(pulseUp))

        return container
    }

    // MARK: - Relationship Line

    static func buildRelationshipLine(from: SCNVector3, to: SCNVector3, type: RAGRelationship.RelationType) -> SCNNode {
        let container = SCNNode()

        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        guard distance > 0.1 else { return container }

        // Create dashed line using small cylinders
        let dashCount = Int(distance / 0.15)
        let lineColor: NSColor
        switch type {
        case .imports: lineColor = NSColor(hex: "#58A6FF")
        case .references: lineColor = NSColor(hex: "#FF9800")
        case .inherits: lineColor = NSColor(hex: "#9C27B0")
        }

        for i in 0..<dashCount where i % 2 == 0 {
            let t = CGFloat(i) / CGFloat(max(dashCount, 1))
            let pos = SCNVector3(
                from.x + dx * t,
                from.y + dy * t,
                from.z + dz * t
            )

            let dash = SCNSphere(radius: 0.015)
            let dashMat = SCNMaterial()
            dashMat.diffuse.contents = lineColor.withAlphaComponent(0.4)
            dashMat.emission.contents = lineColor
            dashMat.emission.intensity = 0.3
            dash.materials = [dashMat]
            let dashNode = SCNNode(geometry: dash)
            dashNode.position = pos
            container.addChildNode(dashNode)
        }

        return container
    }

    // MARK: - Search Result Highlight

    static func buildSearchHighlight(doc: RAGDocument, snippet: String) -> SCNNode {
        let container = SCNNode()
        container.name = "ragSearchHighlight_\(doc.id)"

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        container.constraints = [billboard]

        let panelWidth: CGFloat = 3.5
        let panelHeight: CGFloat = 1.5

        // Background
        let bg = SCNPlane(width: panelWidth, height: panelHeight)
        let bgMat = SCNMaterial()
        bgMat.diffuse.contents = NSColor(hex: "#0D1117").withAlphaComponent(0.92)
        bgMat.emission.contents = NSColor(hex: "#161B22")
        bgMat.emission.intensity = 0.1
        bgMat.isDoubleSided = true
        bg.materials = [bgMat]
        container.addChildNode(SCNNode(geometry: bg))

        // Accent border
        let nodeColor = NSColor(hex: doc.fileType.colorHex)
        let border = SCNPlane(width: panelWidth + 0.04, height: panelHeight + 0.04)
        let borderMat = SCNMaterial()
        borderMat.diffuse.contents = nodeColor.withAlphaComponent(0.3)
        borderMat.emission.contents = nodeColor
        borderMat.emission.intensity = 0.6
        borderMat.isDoubleSided = true
        border.materials = [borderMat]
        let borderNode = SCNNode(geometry: border)
        borderNode.position = SCNVector3(0, 0, -0.005)
        container.addChildNode(borderNode)

        // File name header
        let headerText = SCNText(string: doc.fileName, extrusionDepth: 0.005)
        headerText.font = NSFont(name: "Menlo-Bold", size: 0.09) ?? NSFont.monospacedSystemFont(ofSize: 0.09, weight: .bold)
        headerText.flatness = 0.3
        let headerMat = SCNMaterial()
        headerMat.diffuse.contents = NSColor.white
        headerMat.emission.contents = NSColor.white
        headerMat.emission.intensity = 0.3
        headerText.materials = [headerMat]
        let headerNode = SCNNode(geometry: headerText)
        headerNode.position = SCNVector3(-Float(panelWidth / 2) + 0.1, Float(panelHeight / 2) - 0.25, 0.01)
        headerNode.scale = SCNVector3(0.6, 0.6, 0.6)
        container.addChildNode(headerNode)

        // Snippet text
        let cleanSnippet = snippet
            .replacingOccurrences(of: ">>>", with: "")
            .replacingOccurrences(of: "<<<", with: "")
        let snippetStr = String(cleanSnippet.prefix(120))
        let snippetText = SCNText(string: snippetStr, extrusionDepth: 0.002)
        snippetText.font = NSFont(name: "Menlo", size: 0.06) ?? NSFont.monospacedSystemFont(ofSize: 0.06, weight: .regular)
        snippetText.flatness = 0.4
        snippetText.containerFrame = CGRect(x: 0, y: 0, width: Double(panelWidth - 0.4) / 0.45, height: 4)
        snippetText.isWrapped = true
        let snippetMat = SCNMaterial()
        snippetMat.diffuse.contents = NSColor(hex: "#C9D1D9")
        snippetMat.emission.contents = NSColor(hex: "#C9D1D9")
        snippetMat.emission.intensity = 0.1
        snippetText.materials = [snippetMat]
        let snippetNode = SCNNode(geometry: snippetText)
        snippetNode.position = SCNVector3(-Float(panelWidth / 2) + 0.1, Float(panelHeight / 2) - 0.5, 0.01)
        snippetNode.scale = SCNVector3(0.45, 0.45, 0.45)
        container.addChildNode(snippetNode)

        // Bob animation
        let bobUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 2.2)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 2.2)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return container
    }
}
