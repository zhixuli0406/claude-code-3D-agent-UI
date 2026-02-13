import SceneKit

// MARK: - L2: Smart Scheduling Visualization

struct SmartSchedulingVisualizationBuilder {

    static func buildScheduleVisualization(tasks: [ScheduledTask], timeSlots: [TimeSlot]) -> SCNNode {
        let container = SCNNode()
        container.name = "schedulingVisualization"

        // Build timeline bar
        let timelineNode = buildTimelineBar(timeSlots: timeSlots)
        container.addChildNode(timelineNode)

        // Build task nodes
        for (i, task) in tasks.prefix(6).enumerated() {
            let taskNode = buildTaskNode(task: task, index: i, total: min(tasks.count, 6))
            container.addChildNode(taskNode)
        }

        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 90.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildTimelineBar(timeSlots: [TimeSlot]) -> SCNNode {
        let node = SCNNode()
        node.name = "scheduleTimeline"

        let barGeo = SCNBox(width: 6.0, height: 0.05, length: 0.3, chamferRadius: 0.02)
        let barMat = SCNMaterial()
        barMat.diffuse.contents = NSColor.white.withAlphaComponent(0.15)
        barMat.emission.contents = NSColor.white
        barMat.emission.intensity = 0.05
        barGeo.materials = [barMat]
        let barNode = SCNNode(geometry: barGeo)
        barNode.position = SCNVector3(0, -0.5, 0)
        node.addChildNode(barNode)

        // Utilization indicators
        for (i, slot) in timeSlots.prefix(12).enumerated() {
            let slotGeo = SCNBox(width: 0.4, height: CGFloat(slot.utilizationPercent) * 0.5 + 0.05, length: 0.2, chamferRadius: 0.02)
            let slotMat = SCNMaterial()
            let color = slot.utilizationPercent > 0.7 ? "#F44336" : (slot.utilizationPercent > 0.4 ? "#FF9800" : "#4CAF50")
            slotMat.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.6)
            slotMat.emission.contents = NSColor(hex: color)
            slotMat.emission.intensity = 0.2
            slotGeo.materials = [slotMat]
            let slotNode = SCNNode(geometry: slotGeo)
            let x = Float(i) * 0.5 - 2.75
            slotNode.position = SCNVector3(x, -0.3, 0)
            node.addChildNode(slotNode)
        }

        return node
    }

    private static func buildTaskNode(task: ScheduledTask, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "schedTask_\(task.id.uuidString)"

        let size: CGFloat = task.priority == .critical ? 0.35 : (task.priority == .high ? 0.3 : 0.25)
        let sphereGeo = SCNSphere(radius: size)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: task.priority.hexColor).withAlphaComponent(0.8)
        mat.emission.contents = NSColor(hex: task.priority.hexColor)
        mat.emission.intensity = 0.4
        sphereGeo.materials = [mat]
        let sphereNode = SCNNode(geometry: sphereGeo)
        node.addChildNode(sphereNode)

        // Task name label
        let label = buildLabel(String(task.name.prefix(15)),
                              color: NSColor.white.withAlphaComponent(0.8),
                              fontSize: 0.05)
        label.position = SCNVector3(0, Float(size) + 0.15, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Position in arc
        let angle = Float(index) * (Float.pi / Float(max(total - 1, 1))) - Float.pi / 2
        let radius: Float = 1.5
        node.position = SCNVector3(cos(angle) * radius, sin(angle) * 0.5 + 0.3, sin(angle) * 0.3)

        // Status ring
        let ringGeo = SCNTorus(ringRadius: CGFloat(size) + 0.05, pipeRadius: 0.01)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(hex: task.status.hexColor).withAlphaComponent(0.6)
        ringMat.emission.contents = NSColor(hex: task.status.hexColor)
        ringMat.emission.intensity = 0.3
        ringGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: ringGeo)
        node.addChildNode(ringNode)

        // Pulse for running tasks
        if task.status == .running {
            let pulse = SCNAction.sequence([
                .scale(to: 1.1, duration: 0.6),
                .scale(to: 1.0, duration: 0.6)
            ])
            sphereNode.runAction(.repeatForever(pulse))
        }

        // Bob animation
        let bobDuration = 1.8 + Double(index % 3) * 0.3
        let bobUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(.sequence([bobUp, bobDown])))

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
