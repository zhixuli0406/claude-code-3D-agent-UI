import SceneKit

// MARK: - I5: Docker Container Visualization

struct DockerVisualizationBuilder {

    // MARK: - Container Visualization

    static func buildContainerVisualization(containers: [DockerContainer]) -> SCNNode {
        let container = SCNNode()
        container.name = "dockerVisualization"

        let containersToShow = Array(containers.prefix(12))
        guard !containersToShow.isEmpty else { return container }

        // Arrange containers in a grid layout
        let columns = min(4, containersToShow.count)
        let spacingX: Float = 2.2
        let spacingZ: Float = 2.0

        for (i, dockerContainer) in containersToShow.enumerated() {
            let col = i % columns
            let row = i / columns
            let totalCols = min(columns, containersToShow.count)
            let x = Float(col) * spacingX - Float(totalCols - 1) * spacingX / 2.0
            let z = Float(row) * spacingZ

            let containerNode = buildContainerBox(
                dockerContainer: dockerContainer, index: i, total: containersToShow.count
            )
            containerNode.position = SCNVector3(x, 0, z)
            container.addChildNode(containerNode)
        }

        // Title label
        let titleLabel = buildLabel("DOCKER CONTAINERS", color: NSColor(hex: "#2196F3"), fontSize: 0.15)
        titleLabel.position = SCNVector3(0, 3.5, -1.0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        titleLabel.constraints = [billboard]
        container.addChildNode(titleLabel)

        // Slow rotation
        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 80.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    // MARK: - Container Box

    private static func buildContainerBox(dockerContainer: DockerContainer, index: Int, total: Int) -> SCNNode {
        let container = SCNNode()
        container.name = "dockerBox_\(dockerContainer.id.uuidString)"

        let statusColor = NSColor(hex: dockerContainer.status.hexColor)
        let isRunning = dockerContainer.status == .running

        // Main container box (translucent)
        let boxWidth: CGFloat = 1.4
        let boxHeight: CGFloat = 0.8
        let boxDepth: CGFloat = 0.8
        let box = SCNBox(width: boxWidth, height: boxHeight, length: boxDepth, chamferRadius: 0.05)
        let boxMat = SCNMaterial()
        boxMat.diffuse.contents = statusColor.withAlphaComponent(isRunning ? 0.35 : 0.15)
        boxMat.emission.contents = statusColor
        boxMat.emission.intensity = isRunning ? 0.4 : 0.1
        boxMat.isDoubleSided = true
        boxMat.transparency = isRunning ? 0.7 : 0.4
        box.materials = [boxMat]
        let boxNode = SCNNode(geometry: box)
        boxNode.position = SCNVector3(0, Float(boxHeight / 2), 0)
        container.addChildNode(boxNode)

        // Animated glow for running containers
        if isRunning {
            let glowPulse = SCNAction.customAction(duration: 2.0) { node, elapsed in
                let t = Float(elapsed) / 2.0
                let intensity = 0.3 + 0.25 * sin(t * Float.pi * 2)
                node.geometry?.materials.first?.emission.intensity = CGFloat(intensity)
            }
            boxNode.runAction(.repeatForever(glowPulse))
        }

        // Container wireframe edges (outline effect)
        let edgeGeo = SCNBox(width: boxWidth + 0.02, height: boxHeight + 0.02, length: boxDepth + 0.02, chamferRadius: 0.06)
        let edgeMat = SCNMaterial()
        edgeMat.diffuse.contents = statusColor.withAlphaComponent(0.3)
        edgeMat.emission.contents = statusColor
        edgeMat.emission.intensity = isRunning ? 0.5 : 0.15
        edgeMat.fillMode = .lines
        edgeGeo.materials = [edgeMat]
        let edgeNode = SCNNode(geometry: edgeGeo)
        edgeNode.position = SCNVector3(0, Float(boxHeight / 2), 0)
        container.addChildNode(edgeNode)

        // Container name label
        let displayName = String(dockerContainer.name.prefix(18))
        let nameText = SCNText(string: displayName, extrusionDepth: 0.005)
        nameText.font = NSFont(name: "Menlo-Bold", size: 0.07) ?? NSFont.monospacedSystemFont(ofSize: 0.07, weight: .bold)
        nameText.flatness = 0.3
        let nameMat = SCNMaterial()
        nameMat.diffuse.contents = NSColor.white
        nameMat.emission.contents = NSColor.white
        nameMat.emission.intensity = 0.3
        nameText.materials = [nameMat]
        let nameNode = SCNNode(geometry: nameText)
        let (nameMin, nameMax) = nameNode.boundingBox
        let nameWidth = nameMax.x - nameMin.x
        nameNode.position = SCNVector3(-nameWidth / 2, boxHeight + 0.15, 0)
        nameNode.scale = SCNVector3(0.5, 0.5, 0.5)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        nameNode.constraints = [billboard]
        container.addChildNode(nameNode)

        // Image name label
        let imageStr = String(dockerContainer.image.prefix(22))
        let imageLabel = buildLabel(imageStr, color: NSColor(hex: "#8B949E"), fontSize: 0.04)
        imageLabel.position = SCNVector3(0, Float(boxHeight) + 0.05, 0)
        let imgBillboard = SCNBillboardConstraint()
        imgBillboard.freeAxes = .Y
        imageLabel.constraints = [imgBillboard]
        container.addChildNode(imageLabel)

        // Status indicator sphere
        let statusSphere = SCNSphere(radius: 0.06)
        let statusMat = SCNMaterial()
        statusMat.diffuse.contents = statusColor
        statusMat.emission.contents = statusColor
        statusMat.emission.intensity = isRunning ? 0.8 : 0.2
        statusSphere.materials = [statusMat]
        let statusNode = SCNNode(geometry: statusSphere)
        statusNode.position = SCNVector3(Float(boxWidth / 2) + 0.1, Float(boxHeight), 0)
        container.addChildNode(statusNode)

        // Status pulse for running
        if isRunning {
            let statusPulse = SCNAction.sequence([
                .scale(to: 1.3, duration: 0.6),
                .scale(to: 1.0, duration: 0.6)
            ])
            statusNode.runAction(.repeatForever(statusPulse))
        }

        // CPU usage gauge
        let cpuGauge = buildResourceGauge(
            label: "CPU",
            value: dockerContainer.cpuUsage / 100.0,
            color: cpuGaugeColor(dockerContainer.cpuUsage)
        )
        cpuGauge.position = SCNVector3(-Float(boxWidth / 2) + 0.3, -0.15, Float(boxDepth / 2) + 0.1)
        let cpuBillboard = SCNBillboardConstraint()
        cpuBillboard.freeAxes = .Y
        cpuGauge.constraints = [cpuBillboard]
        container.addChildNode(cpuGauge)

        // Memory usage gauge
        let memGauge = buildResourceGauge(
            label: "MEM",
            value: dockerContainer.memoryUsagePercent,
            color: memGaugeColor(dockerContainer.memoryUsagePercent)
        )
        memGauge.position = SCNVector3(Float(boxWidth / 2) - 0.3, -0.15, Float(boxDepth / 2) + 0.1)
        let memBillboard = SCNBillboardConstraint()
        memBillboard.freeAxes = .Y
        memGauge.constraints = [memBillboard]
        container.addChildNode(memGauge)

        // Port mappings as small indicators
        for (portIdx, port) in dockerContainer.ports.prefix(3).enumerated() {
            let portStr = "\(port.hostPort):\(port.containerPort)"
            let portLabel = buildLabel(portStr, color: NSColor(hex: "#58A6FF"), fontSize: 0.035)
            portLabel.position = SCNVector3(
                0,
                -0.2 - Float(portIdx) * 0.1,
                0
            )
            let portBillboard = SCNBillboardConstraint()
            portBillboard.freeAxes = .Y
            portLabel.constraints = [portBillboard]
            container.addChildNode(portLabel)
        }

        // Floating bob animation
        let bobDuration = 2.0 + Double(index % 4) * 0.35
        let bobUp = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: bobDuration)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: bobDuration)
        bobDown.timingMode = .easeInEaseOut
        container.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        return container
    }

    // MARK: - Resource Gauge

    private static func buildResourceGauge(label: String, value: Double, color: NSColor) -> SCNNode {
        let container = SCNNode()
        container.name = "gauge_\(label)"

        let gaugeWidth: CGFloat = 0.4
        let gaugeHeight: CGFloat = 0.06

        // Background track
        let trackGeo = SCNBox(width: gaugeWidth, height: gaugeHeight, length: 0.02, chamferRadius: 0.01)
        let trackMat = SCNMaterial()
        trackMat.diffuse.contents = NSColor(hex: "#30363D").withAlphaComponent(0.6)
        trackGeo.materials = [trackMat]
        let trackNode = SCNNode(geometry: trackGeo)
        container.addChildNode(trackNode)

        // Fill bar
        let fillWidth = gaugeWidth * CGFloat(min(1.0, max(0.0, value)))
        if fillWidth > 0.01 {
            let fillGeo = SCNBox(width: fillWidth, height: gaugeHeight - 0.01, length: 0.025, chamferRadius: 0.008)
            let fillMat = SCNMaterial()
            fillMat.diffuse.contents = color.withAlphaComponent(0.8)
            fillMat.emission.contents = color
            fillMat.emission.intensity = 0.4
            fillGeo.materials = [fillMat]
            let fillNode = SCNNode(geometry: fillGeo)
            let offset = (gaugeWidth - fillWidth) / 2.0
            fillNode.position = SCNVector3(-Float(offset), 0, 0.005)
            container.addChildNode(fillNode)
        }

        // Label
        let labelText = SCNText(string: label, extrusionDepth: 0.002)
        labelText.font = NSFont(name: "Menlo-Bold", size: 0.03) ?? NSFont.monospacedSystemFont(ofSize: 0.03, weight: .bold)
        labelText.flatness = 0.4
        let labelMat = SCNMaterial()
        labelMat.diffuse.contents = NSColor.white.withAlphaComponent(0.6)
        labelMat.emission.contents = NSColor.white
        labelMat.emission.intensity = 0.1
        labelText.materials = [labelMat]
        let labelNode = SCNNode(geometry: labelText)
        labelNode.position = SCNVector3(-Float(gaugeWidth / 2), Float(gaugeHeight / 2) + 0.02, 0)
        labelNode.scale = SCNVector3(0.4, 0.4, 0.4)
        container.addChildNode(labelNode)

        // Value percentage
        let valStr = String(format: "%.0f%%", value * 100)
        let valText = SCNText(string: valStr, extrusionDepth: 0.002)
        valText.font = NSFont(name: "Menlo", size: 0.025) ?? NSFont.monospacedSystemFont(ofSize: 0.025, weight: .regular)
        valText.flatness = 0.4
        let valMat = SCNMaterial()
        valMat.diffuse.contents = color
        valMat.emission.contents = color
        valMat.emission.intensity = 0.3
        valText.materials = [valMat]
        let valNode = SCNNode(geometry: valText)
        valNode.position = SCNVector3(Float(gaugeWidth / 2) - 0.08, Float(gaugeHeight / 2) + 0.02, 0)
        valNode.scale = SCNVector3(0.4, 0.4, 0.4)
        container.addChildNode(valNode)

        return container
    }

    // MARK: - Helpers

    private static func cpuGaugeColor(_ cpuPercent: Double) -> NSColor {
        if cpuPercent < 50 { return NSColor(hex: "#4CAF50") }
        if cpuPercent < 80 { return NSColor(hex: "#FF9800") }
        return NSColor(hex: "#F44336")
    }

    private static func memGaugeColor(_ memPercent: Double) -> NSColor {
        if memPercent < 0.5 { return NSColor(hex: "#4CAF50") }
        if memPercent < 0.8 { return NSColor(hex: "#FF9800") }
        return NSColor(hex: "#F44336")
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
