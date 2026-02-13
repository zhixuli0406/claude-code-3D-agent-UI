import SceneKit

// MARK: - J4: Data Flow Animation Visualization

struct DataFlowVisualizationBuilder {

    static func buildDataFlowVisualization(flows: [TokenFlowEvent], pipeline: [IOPipelineStage], toolCalls: [ToolCallChainEntry]) -> SCNNode {
        let container = SCNNode()
        container.name = "dataFlowVisualization"

        // Build token stream particles
        let tokenStream = buildTokenStream(flows: flows)
        tokenStream.position = SCNVector3(-1.5, 0, 0)
        container.addChildNode(tokenStream)

        // Build IO pipeline
        let pipelineNode = buildIOPipeline(stages: pipeline)
        pipelineNode.position = SCNVector3(0, 0, 0)
        container.addChildNode(pipelineNode)

        // Build tool call chain
        let toolChain = buildToolCallChain(calls: toolCalls)
        toolChain.position = SCNVector3(1.5, 0, 0)
        container.addChildNode(toolChain)

        // Title label
        let title = buildLabel("Data Flow", color: NSColor(hex: "#00BCD4"), fontSize: 0.1)
        title.position = SCNVector3(0, 2.0, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        title.constraints = [billboard]
        container.addChildNode(title)

        return container
    }

    // MARK: - Token Stream

    private static func buildTokenStream(flows: [TokenFlowEvent]) -> SCNNode {
        let node = SCNNode()
        node.name = "tokenStream"

        for (i, flow) in flows.prefix(10).enumerated() {
            let particleNode = buildTokenParticle(flow: flow, index: i)
            node.addChildNode(particleNode)
        }

        return node
    }

    private static func buildTokenParticle(flow: TokenFlowEvent, index: Int) -> SCNNode {
        let node = SCNNode()

        // Particle size based on token count
        let size = CGFloat(max(0.03, min(0.12, Double(flow.tokenCount) / 500.0)))
        let sphere = SCNSphere(radius: size)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: flow.flowType.hexColor).withAlphaComponent(flow.isActive ? 0.9 : 0.3)
        mat.emission.contents = NSColor(hex: flow.flowType.hexColor)
        mat.emission.intensity = flow.isActive ? 0.6 : 0.1
        sphere.materials = [mat]
        node.geometry = sphere

        let yPos = Float(index) * 0.3
        node.position = SCNVector3(0, yPos, 0)

        if flow.isActive {
            // Flowing animation
            let moveUp = SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 1.0 + Double(index) * 0.1)
            moveUp.timingMode = .easeInEaseOut
            let moveDown = SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 1.0 + Double(index) * 0.1)
            moveDown.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([moveUp, moveDown])))

            // Pulse
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.4, duration: 0.6),
                .fadeOpacity(to: 1.0, duration: 0.6)
            ])
            node.runAction(.repeatForever(pulse))
        }

        // Token count label
        let label = buildLabel("\(flow.tokenCount)", color: NSColor.white.withAlphaComponent(0.6), fontSize: 0.03)
        label.position = SCNVector3(Float(size) + 0.05, 0, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        return node
    }

    // MARK: - IO Pipeline

    private static func buildIOPipeline(stages: [IOPipelineStage]) -> SCNNode {
        let node = SCNNode()
        node.name = "ioPipeline"

        for (i, stage) in stages.prefix(6).enumerated() {
            let stageNode = buildPipelineStageNode(stage: stage, index: i)
            node.addChildNode(stageNode)

            // Connection line between stages
            if i > 0 {
                let lineGeo = SCNCylinder(radius: 0.015, height: 0.15)
                let lineMat = SCNMaterial()
                lineMat.diffuse.contents = NSColor.white.withAlphaComponent(0.2)
                lineMat.emission.contents = NSColor.white
                lineMat.emission.intensity = 0.1
                lineGeo.materials = [lineMat]
                let lineNode = SCNNode(geometry: lineGeo)
                lineNode.position = SCNVector3(0, Float(i) * 0.45 - 0.22, 0)
                node.addChildNode(lineNode)
            }
        }

        return node
    }

    private static func buildPipelineStageNode(stage: IOPipelineStage, index: Int) -> SCNNode {
        let node = SCNNode()

        let box = SCNBox(width: 0.7, height: 0.25, length: 0.3, chamferRadius: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: stage.status.hexColor).withAlphaComponent(0.8)
        mat.emission.contents = NSColor(hex: stage.status.hexColor)
        mat.emission.intensity = stage.status == .active ? 0.5 : 0.2
        box.materials = [mat]
        node.geometry = box

        node.position = SCNVector3(0, Float(index) * 0.45, 0)

        // Stage name label
        let label = buildLabel(String(stage.name.prefix(15)), color: NSColor.white.withAlphaComponent(0.8), fontSize: 0.04)
        label.position = SCNVector3(0.4, Float(index) * 0.45, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]

        let parent = SCNNode()
        parent.addChildNode(node)
        parent.addChildNode(label)

        if stage.status == .active {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.5, duration: 0.5),
                .fadeOpacity(to: 1.0, duration: 0.5)
            ])
            node.runAction(.repeatForever(pulse))
        }

        return parent
    }

    // MARK: - Tool Call Chain

    private static func buildToolCallChain(calls: [ToolCallChainEntry]) -> SCNNode {
        let node = SCNNode()
        node.name = "toolCallChain"

        for (i, call) in calls.prefix(8).enumerated() {
            let callNode = buildToolCallNode(call: call, index: i)
            node.addChildNode(callNode)

            // Arrow between calls
            if i > 0 {
                let arrowGeo = SCNCone(topRadius: 0, bottomRadius: 0.025, height: 0.1)
                let arrowMat = SCNMaterial()
                arrowMat.diffuse.contents = NSColor(hex: "#E91E63").withAlphaComponent(0.6)
                arrowMat.emission.contents = NSColor(hex: "#E91E63")
                arrowMat.emission.intensity = 0.3
                arrowGeo.materials = [arrowMat]
                let arrowNode = SCNNode(geometry: arrowGeo)
                arrowNode.position = SCNVector3(0, Float(i) * 0.4 - 0.2, 0)
                node.addChildNode(arrowNode)
            }
        }

        return node
    }

    private static func buildToolCallNode(call: ToolCallChainEntry, index: Int) -> SCNNode {
        let node = SCNNode()

        let capsule = SCNCapsule(capRadius: 0.06, height: 0.2)
        let mat = SCNMaterial()
        let color = DataFlowType.toolCall.hexColor
        mat.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.8)
        mat.emission.contents = NSColor(hex: color)
        mat.emission.intensity = call.output != nil ? 0.2 : 0.5
        capsule.materials = [mat]
        node.geometry = capsule

        node.position = SCNVector3(0, Float(index) * 0.4, 0)

        // Tool name label
        let label = buildLabel(call.toolName, color: NSColor.white.withAlphaComponent(0.8), fontSize: 0.04)
        label.position = SCNVector3(0.15, 0, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Duration indicator
        if let dur = call.duration {
            let durLabel = buildLabel(String(format: "%.1fs", dur), color: NSColor.white.withAlphaComponent(0.4), fontSize: 0.03)
            durLabel.position = SCNVector3(0.15, -0.08, 0)
            durLabel.constraints = [billboard]
            node.addChildNode(durLabel)
        }

        return node
    }

    // MARK: - Helpers

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
