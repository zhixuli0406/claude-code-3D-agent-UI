import SceneKit

// MARK: - L1: Workflow Automation Visualization

struct WorkflowVisualizationBuilder {

    static func buildWorkflowVisualization(workflows: [Workflow]) -> SCNNode {
        let container = SCNNode()
        container.name = "workflowVisualization"

        guard !workflows.isEmpty else { return container }

        for (i, workflow) in workflows.prefix(4).enumerated() {
            let workflowNode = buildWorkflowNode(workflow: workflow, index: i, total: min(workflows.count, 4))
            container.addChildNode(workflowNode)
        }

        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 80.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildWorkflowNode(workflow: Workflow, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "workflow_\(workflow.id.uuidString)"
        let spacing: Float = 2.5
        let startX = -Float(total - 1) * spacing / 2.0
        node.position = SCNVector3(startX + Float(index) * spacing, 0, 0)

        // Workflow steps as connected nodes
        for (stepIdx, step) in workflow.steps.enumerated() {
            let stepNode = buildStepNode(step: step, index: stepIdx)
            node.addChildNode(stepNode)

            // Connection line
            if stepIdx > 0 {
                let lineNode = buildConnectionLine(from: stepIdx - 1, to: stepIdx)
                node.addChildNode(lineNode)
            }
        }

        // Trigger indicator at bottom
        let triggerNode = buildTriggerNode(workflow.trigger)
        triggerNode.position = SCNVector3(0, -0.6, 0)
        node.addChildNode(triggerNode)

        // Workflow name label
        let nameLabel = buildLabel(String(workflow.name.prefix(18)),
                                   color: NSColor(hex: "#C9D1D9"),
                                   fontSize: 0.07)
        let topY = Float(workflow.steps.count) * 0.5 + 0.3
        nameLabel.position = SCNVector3(0, topY, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        nameLabel.constraints = [billboard]
        node.addChildNode(nameLabel)

        // Status sphere
        let statusSphere = SCNSphere(radius: 0.1)
        let statusMat = SCNMaterial()
        statusMat.diffuse.contents = NSColor(hex: workflow.status.hexColor)
        statusMat.emission.contents = NSColor(hex: workflow.status.hexColor)
        statusMat.emission.intensity = 0.5
        statusSphere.materials = [statusMat]
        let statusNode = SCNNode(geometry: statusSphere)
        statusNode.position = SCNVector3(0, topY + 0.25, 0)
        node.addChildNode(statusNode)

        // Floating animation
        let bobDuration = 2.0 + Double(index % 3) * 0.3
        let bobUp = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return node
    }

    private static func buildStepNode(step: WorkflowStep, index: Int) -> SCNNode {
        let geo: SCNGeometry
        switch step.type {
        case .condition:
            // Diamond shape for conditions
            let box = SCNBox(width: 0.5, height: 0.5, length: 0.3, chamferRadius: 0.02)
            geo = box
        case .parallel:
            // Wide box for parallel
            let box = SCNBox(width: 0.7, height: 0.25, length: 0.3, chamferRadius: 0.05)
            geo = box
        default:
            let box = SCNBox(width: 0.6, height: 0.25, length: 0.3, chamferRadius: 0.05)
            geo = box
        }

        let color = step.type == .condition ? "#FF9800" : (step.type == .parallel ? "#9C27B0" : "#2196F3")
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.8)
        mat.emission.contents = NSColor(hex: color)
        mat.emission.intensity = 0.3
        geo.materials = [mat]

        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(0, Float(index) * 0.5, 0)

        if step.type == .condition {
            node.eulerAngles = SCNVector3(0, 0, Float.pi / 4)
        }

        // Step name label
        let label = buildLabel(String(step.name.prefix(12)),
                              color: NSColor.white.withAlphaComponent(0.8),
                              fontSize: 0.04)
        label.position = SCNVector3(0.4, Float(index) * 0.5, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]

        let parent = SCNNode()
        parent.addChildNode(node)
        parent.addChildNode(label)

        // Pulse for running steps
        if step.status == .running {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.5, duration: 0.5),
                .fadeOpacity(to: 1.0, duration: 0.5)
            ])
            node.runAction(.repeatForever(pulse))
        }

        return parent
    }

    private static func buildTriggerNode(_ trigger: WorkflowTrigger) -> SCNNode {
        let geo = SCNCapsule(capRadius: 0.08, height: 0.25)
        let mat = SCNMaterial()
        let color = trigger.isEnabled ? "#4CAF50" : "#9E9E9E"
        mat.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.7)
        mat.emission.contents = NSColor(hex: color)
        mat.emission.intensity = 0.3
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    private static func buildConnectionLine(from: Int, to: Int) -> SCNNode {
        let lineGeo = SCNCylinder(radius: 0.015, height: 0.2)
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = NSColor.white.withAlphaComponent(0.3)
        lineMat.emission.contents = NSColor.white
        lineMat.emission.intensity = 0.1
        lineGeo.materials = [lineMat]
        let lineNode = SCNNode(geometry: lineGeo)
        lineNode.position = SCNVector3(0, Float(to) * 0.5 - 0.25, 0)
        return lineNode
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
