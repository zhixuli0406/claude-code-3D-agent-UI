import SceneKit

// MARK: - J1: Code Knowledge Graph Visualization

struct CodeKnowledgeGraphVisualizationBuilder {

    static func buildKnowledgeGraph(nodes: [CodeFileNode], edges: [CodeDependencyEdge]) -> SCNNode {
        let container = SCNNode()
        container.name = "codeKnowledgeGraphVisualization"

        guard !nodes.isEmpty else { return container }

        // Position nodes in a circular layout
        let radius: Float = 2.5
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($1.id, $0) })

        for (i, node) in nodes.prefix(15).enumerated() {
            let angle = Float(i) / Float(min(nodes.count, 15)) * Float.pi * 2
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            let fileNode = buildFileNode(node: node, index: i)
            fileNode.position = SCNVector3(x, 0, z)
            container.addChildNode(fileNode)
        }

        // Build edges
        for edge in edges {
            guard let srcIdx = nodeMap[edge.sourceId],
                  let tgtIdx = nodeMap[edge.targetId],
                  srcIdx < 15, tgtIdx < 15 else { continue }

            let srcAngle = Float(srcIdx) / Float(min(nodes.count, 15)) * Float.pi * 2
            let tgtAngle = Float(tgtIdx) / Float(min(nodes.count, 15)) * Float.pi * 2

            let srcPos = SCNVector3(cos(srcAngle) * radius, 0, sin(srcAngle) * radius)
            let tgtPos = SCNVector3(cos(tgtAngle) * radius, 0, sin(tgtAngle) * radius)

            let edgeNode = buildEdge(from: srcPos, to: tgtPos, type: edge.edgeType, isActive: edge.isActive)
            container.addChildNode(edgeNode)
        }

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 80.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildFileNode(node: CodeFileNode, index: Int) -> SCNNode {
        let scnNode = SCNNode()
        scnNode.name = "codeFile_\(node.id.uuidString)"

        // File sphere, size based on line count
        let size = CGFloat(max(0.1, min(0.4, Double(node.lineCount) / 500.0)))
        let sphere = SCNSphere(radius: size)
        let mat = SCNMaterial()
        let alpha: CGFloat = node.isHighlighted ? 1.0 : 0.7
        mat.diffuse.contents = NSColor(hex: node.type.hexColor).withAlphaComponent(alpha)
        mat.emission.contents = NSColor(hex: node.type.hexColor)
        mat.emission.intensity = node.isHighlighted ? 0.8 : 0.3
        sphere.materials = [mat]

        let sphereNode = SCNNode(geometry: sphere)
        scnNode.addChildNode(sphereNode)

        // Label
        let label = buildLabel(String(node.name.prefix(15)), color: NSColor.white.withAlphaComponent(0.8), fontSize: 0.06)
        label.position = SCNVector3(0, Float(size) + 0.1, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        scnNode.addChildNode(label)

        // Floating animation
        let bobDuration = 2.0 + Double(index % 4) * 0.3
        let bobUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        scnNode.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        // Pulse for highlighted nodes
        if node.isHighlighted {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.6, duration: 0.5),
                .fadeOpacity(to: 1.0, duration: 0.5)
            ])
            sphereNode.runAction(.repeatForever(pulse))
        }

        return scnNode
    }

    private static func buildEdge(from: SCNVector3, to: SCNVector3, type: DependencyType, isActive: Bool) -> SCNNode {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        let cylinder = SCNCylinder(radius: isActive ? 0.02 : 0.008, height: CGFloat(distance))
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: type.hexColor).withAlphaComponent(isActive ? 0.8 : 0.3)
        mat.emission.contents = NSColor(hex: type.hexColor)
        mat.emission.intensity = isActive ? 0.4 : 0.1
        cylinder.materials = [mat]

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2)
        node.look(at: to)
        node.eulerAngles.x += .pi / 2

        if isActive {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.4, duration: 0.6),
                .fadeOpacity(to: 1.0, duration: 0.6)
            ])
            node.runAction(.repeatForever(pulse))
        }

        return node
    }

    private static func buildLabel(_ text: String, color: NSColor, fontSize: CGFloat) -> SCNNode {
        let scnText = SCNText(string: text, extrusionDepth: 0.01)
        scnText.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        scnText.flatness = 0.1
        scnText.firstMaterial?.diffuse.contents = color
        scnText.firstMaterial?.emission.contents = color
        scnText.firstMaterial?.emission.intensity = 0.3

        let node = SCNNode(geometry: scnText)
        let (minBound, maxBound) = node.boundingBox
        let textWidth = maxBound.x - minBound.x
        node.pivot = SCNMatrix4MakeTranslation(textWidth / 2, 0, 0)
        return node
    }
}
