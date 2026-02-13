import SceneKit

// MARK: - I1: CI/CD Pipeline Visualization

struct CICDVisualizationBuilder {

    // MARK: - Pipeline Visualization

    static func buildPipelineVisualization(pipelines: [CICDPipeline]) -> SCNNode {
        let container = SCNNode()
        container.name = "cicdVisualization"

        guard !pipelines.isEmpty else { return container }

        // Build pipeline stages as connected cylinders
        for (i, pipeline) in pipelines.prefix(5).enumerated() {
            let pipelineNode = buildPipelineNode(pipeline: pipeline, index: i, total: min(pipelines.count, 5))
            container.addChildNode(pipelineNode)
        }

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 60.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    // MARK: - Pipeline Node

    private static func buildPipelineNode(pipeline: CICDPipeline, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "cicdPipeline_\(pipeline.id.uuidString)"
        let spacing: Float = 2.0
        let startX = -Float(total - 1) * spacing / 2.0
        node.position = SCNVector3(startX + Float(index) * spacing, 0, 0)

        // Pipeline stages as stacked blocks
        for (stageIdx, stage) in pipeline.stages.enumerated() {
            let stageGeo = SCNBox(width: 0.8, height: 0.3, length: 0.4, chamferRadius: 0.05)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(hex: stage.status.hexColor).withAlphaComponent(0.85)
            mat.emission.contents = NSColor(hex: stage.status.hexColor)
            mat.emission.intensity = 0.4
            stageGeo.materials = [mat]

            let stageNode = SCNNode(geometry: stageGeo)
            stageNode.position = SCNVector3(0, Float(stageIdx) * 0.5, 0)
            node.addChildNode(stageNode)

            // Stage name label
            let stageLabel = buildLabel(String(stage.name.prefix(12)),
                                        color: NSColor.white.withAlphaComponent(0.8),
                                        fontSize: 0.05)
            stageLabel.position = SCNVector3(0.45, Float(stageIdx) * 0.5, 0)
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            stageLabel.constraints = [billboard]
            node.addChildNode(stageLabel)

            // Connection line between stages
            if stageIdx > 0 {
                let lineGeo = SCNCylinder(radius: 0.02, height: 0.2)
                let lineMat = SCNMaterial()
                lineMat.diffuse.contents = NSColor.white.withAlphaComponent(0.3)
                lineMat.emission.contents = NSColor.white
                lineMat.emission.intensity = 0.1
                lineGeo.materials = [lineMat]
                let lineNode = SCNNode(geometry: lineGeo)
                lineNode.position = SCNVector3(0, Float(stageIdx) * 0.5 - 0.25, 0)
                node.addChildNode(lineNode)
            }

            // Pulse animation for in-progress stages
            if stage.status == .inProgress {
                let pulse = SCNAction.sequence([
                    .fadeOpacity(to: 0.5, duration: 0.6),
                    .fadeOpacity(to: 1.0, duration: 0.6)
                ])
                stageNode.runAction(.repeatForever(pulse))
            }
        }

        // Pipeline status indicator sphere at the top
        let statusSphere = SCNSphere(radius: 0.12)
        let statusMat = SCNMaterial()
        statusMat.diffuse.contents = NSColor(hex: pipeline.status.hexColor)
        statusMat.emission.contents = NSColor(hex: pipeline.status.hexColor)
        statusMat.emission.intensity = 0.6
        statusSphere.materials = [statusMat]
        let statusNode = SCNNode(geometry: statusSphere)
        let topY = Float(pipeline.stages.count) * 0.5 + 0.2
        statusNode.position = SCNVector3(0, topY, 0)
        node.addChildNode(statusNode)

        // Branch label
        let text = SCNText(string: pipeline.branch, extrusionDepth: 0.01)
        text.font = NSFont.systemFont(ofSize: 0.12, weight: .medium)
        text.flatness = 0.1
        text.firstMaterial?.diffuse.contents = NSColor.white.withAlphaComponent(0.7)
        text.firstMaterial?.emission.contents = NSColor.white
        text.firstMaterial?.emission.intensity = 0.15
        let textNode = SCNNode(geometry: text)
        let (minBound, maxBound) = textNode.boundingBox
        let textWidth = maxBound.x - minBound.x
        textNode.position = SCNVector3(-textWidth / 2, -0.3, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        textNode.constraints = [billboard]
        node.addChildNode(textNode)

        // Pipeline name label above
        let nameLabel = buildLabel(String(pipeline.name.prefix(20)),
                                   color: NSColor(hex: "#C9D1D9"),
                                   fontSize: 0.07)
        nameLabel.position = SCNVector3(0, topY + 0.25, 0)
        let nameBillboard = SCNBillboardConstraint()
        nameBillboard.freeAxes = .Y
        nameLabel.constraints = [nameBillboard]
        node.addChildNode(nameLabel)

        // Pulse animation for running pipeline
        if pipeline.isRunning {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.6, duration: 0.8),
                .fadeOpacity(to: 1.0, duration: 0.8)
            ])
            node.runAction(.repeatForever(pulse))
        }

        // Floating bob animation
        let bobDuration = 2.0 + Double(index % 3) * 0.4
        let bobUp = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(.sequence([bobUp, bobDown])))

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
        // Center the text
        let (minBound, maxBound) = node.boundingBox
        let textWidth = maxBound.x - minBound.x
        node.pivot = SCNMatrix4MakeTranslation(textWidth / 2, 0, 0)

        return node
    }
}
