import SceneKit

// MARK: - M2: Report Export Visualization

struct ReportExportVisualizationBuilder {

    static func buildExportVisualization(jobs: [ExportJob], schedules: [ReportSchedule]) -> SCNNode {
        let container = SCNNode()
        container.name = "reportExportVisualization"

        // Central document hub
        let hubNode = buildDocumentHub()
        hubNode.position = SCNVector3(0, 0.6, 0)
        container.addChildNode(hubNode)

        // Export job nodes
        for (i, job) in jobs.prefix(5).enumerated() {
            let jobNode = buildJobNode(job: job, index: i, total: min(jobs.count, 5))
            container.addChildNode(jobNode)
        }

        // Schedule orbit
        if !schedules.isEmpty {
            let scheduleRing = buildScheduleRing(schedules: Array(schedules.prefix(4)))
            scheduleRing.position = SCNVector3(0, -0.5, 0)
            container.addChildNode(scheduleRing)
        }

        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 75.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildDocumentHub() -> SCNNode {
        let node = SCNNode()

        // Document icon (flat box)
        let docGeo = SCNBox(width: 0.25, height: 0.32, length: 0.02, chamferRadius: 0.01)
        let docMat = SCNMaterial()
        docMat.diffuse.contents = NSColor(hex: "#E91E63").withAlphaComponent(0.5)
        docMat.emission.contents = NSColor(hex: "#E91E63")
        docMat.emission.intensity = 0.4
        docGeo.materials = [docMat]
        let docNode = SCNNode(geometry: docGeo)
        node.addChildNode(docNode)

        // Arrow up indicator
        let arrowGeo = SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.12)
        let arrowMat = SCNMaterial()
        arrowMat.diffuse.contents = NSColor(hex: "#4CAF50").withAlphaComponent(0.7)
        arrowMat.emission.contents = NSColor(hex: "#4CAF50")
        arrowMat.emission.intensity = 0.4
        arrowGeo.materials = [arrowMat]
        let arrowNode = SCNNode(geometry: arrowGeo)
        arrowNode.position = SCNVector3(0.15, 0.1, 0.02)
        node.addChildNode(arrowNode)

        // Pulse animation
        let pulse = SCNAction.sequence([
            .scale(to: 1.05, duration: 1.5),
            .scale(to: 1.0, duration: 1.5)
        ])
        node.runAction(.repeatForever(pulse))

        return node
    }

    private static func buildJobNode(job: ExportJob, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "exportJob_\(job.id)"

        let colorHex = job.status.colorHex
        let size: CGFloat = job.status == .inProgress ? 0.2 : 0.15

        // Format-specific geometry
        let geo: SCNGeometry
        switch job.format {
        case .pdf:
            geo = SCNBox(width: size, height: size * 1.3, length: 0.02, chamferRadius: 0.005)
        case .json:
            geo = SCNBox(width: size, height: size, length: size, chamferRadius: 0.02)
        case .csv:
            geo = SCNCylinder(radius: size / 2, height: 0.02)
        case .markdown:
            geo = SCNBox(width: size * 1.2, height: size, length: 0.02, chamferRadius: 0.005)
        }

        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: colorHex).withAlphaComponent(0.7)
        mat.emission.contents = NSColor(hex: colorHex)
        mat.emission.intensity = job.status == .inProgress ? 0.5 : 0.2
        geo.materials = [mat]
        let geoNode = SCNNode(geometry: geo)
        node.addChildNode(geoNode)

        // In-progress animation
        if job.status == .inProgress {
            let pulse = SCNAction.sequence([
                .fadeOpacity(to: 0.5, duration: 0.5),
                .fadeOpacity(to: 1.0, duration: 0.5)
            ])
            geoNode.runAction(.repeatForever(pulse))
        }

        // Label
        let label = buildLabel(job.format.displayName,
                              color: NSColor.white.withAlphaComponent(0.6),
                              fontSize: 0.03)
        label.position = SCNVector3(0, Float(size) + 0.08, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Position in semicircle
        let angle = Float(index) * (Float.pi / Float(max(total - 1, 1))) - Float.pi / 2
        node.position = SCNVector3(cos(angle) * 1.5, sin(angle) * 0.4, sin(angle) * 0.3)

        return node
    }

    private static func buildScheduleRing(schedules: [ReportSchedule]) -> SCNNode {
        let ring = SCNNode()
        ring.name = "scheduleRing"

        for (i, schedule) in schedules.enumerated() {
            let angle = Float(i) * (2 * Float.pi / Float(schedules.count))
            let radius: Float = 0.8

            let clockGeo = SCNTorus(ringRadius: 0.06, pipeRadius: 0.01)
            let clockMat = SCNMaterial()
            let activeColor = schedule.isActive ? "#4CAF50" : "#9E9E9E"
            clockMat.diffuse.contents = NSColor(hex: activeColor).withAlphaComponent(0.7)
            clockMat.emission.contents = NSColor(hex: activeColor)
            clockMat.emission.intensity = schedule.isActive ? 0.4 : 0.1
            clockGeo.materials = [clockMat]
            let clockNode = SCNNode(geometry: clockGeo)
            clockNode.position = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius)

            if schedule.isActive {
                let spin = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 6)
                clockNode.runAction(.repeatForever(spin))
            }

            ring.addChildNode(clockNode)
        }

        let ringRotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 50)
        ring.runAction(.repeatForever(ringRotate))

        return ring
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
