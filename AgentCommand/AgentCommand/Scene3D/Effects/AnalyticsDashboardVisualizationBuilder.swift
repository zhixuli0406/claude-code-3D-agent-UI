import SceneKit

// MARK: - M1: Analytics Dashboard Visualization

struct AnalyticsDashboardVisualizationBuilder {

    static func buildDashboardVisualization(reports: [DashboardReport], forecasts: [TrendForecast], optimizations: [CostOptimizationTip]) -> SCNNode {
        let container = SCNNode()
        container.name = "analyticsDashboardVisualization"

        // Central analytics hub
        let hubNode = buildHubNode()
        hubNode.position = SCNVector3(0, 0.8, 0)
        container.addChildNode(hubNode)

        // Report widget nodes arranged in arc
        for (i, report) in reports.prefix(4).enumerated() {
            let reportNode = buildReportNode(report: report, index: i, total: min(reports.count, 4))
            container.addChildNode(reportNode)
        }

        // Forecast trend lines
        for (i, forecast) in forecasts.prefix(3).enumerated() {
            let forecastNode = buildForecastNode(forecast: forecast, index: i)
            forecastNode.position = SCNVector3(0, -0.6, Float(i) * 0.6 - 0.6)
            container.addChildNode(forecastNode)
        }

        // Optimization suggestion indicators
        if !optimizations.isEmpty {
            let optRing = buildOptimizationRing(tips: Array(optimizations.prefix(5)))
            optRing.position = SCNVector3(0, -1.2, 0)
            container.addChildNode(optRing)
        }

        let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 80.0)
        container.runAction(.repeatForever(rotate))

        return container
    }

    private static func buildHubNode() -> SCNNode {
        let node = SCNNode()

        // Central sphere
        let sphereGeo = SCNSphere(radius: 0.25)
        let sphereMat = SCNMaterial()
        sphereMat.diffuse.contents = NSColor(hex: "#00BCD4").withAlphaComponent(0.4)
        sphereMat.emission.contents = NSColor(hex: "#00BCD4")
        sphereMat.emission.intensity = 0.5
        sphereMat.isDoubleSided = true
        sphereGeo.materials = [sphereMat]
        let sphereNode = SCNNode(geometry: sphereGeo)
        node.addChildNode(sphereNode)

        // Orbiting ring
        let ringGeo = SCNTorus(ringRadius: 0.4, pipeRadius: 0.012)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(hex: "#4CAF50").withAlphaComponent(0.5)
        ringMat.emission.contents = NSColor(hex: "#4CAF50")
        ringMat.emission.intensity = 0.3
        ringGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: ringGeo)
        ringNode.eulerAngles.x = CGFloat.pi / 4
        node.addChildNode(ringNode)

        let rotateRing = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 10)
        ringNode.runAction(.repeatForever(rotateRing))

        let pulse = SCNAction.sequence([
            .scale(to: 1.1, duration: 2.0),
            .scale(to: 1.0, duration: 2.0)
        ])
        node.runAction(.repeatForever(pulse))

        return node
    }

    private static func buildReportNode(report: DashboardReport, index: Int, total: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "report_\(report.id)"

        // Widget panel (flat box)
        let panelGeo = SCNBox(width: 0.4, height: 0.3, length: 0.02, chamferRadius: 0.01)
        let panelMat = SCNMaterial()
        let widgetCount = report.widgets.count
        let color = widgetCount > 3 ? "#00BCD4" : (widgetCount > 1 ? "#2196F3" : "#9C27B0")
        panelMat.diffuse.contents = NSColor(hex: color).withAlphaComponent(0.6)
        panelMat.emission.contents = NSColor(hex: color)
        panelMat.emission.intensity = 0.3
        panelGeo.materials = [panelMat]
        let panelNode = SCNNode(geometry: panelGeo)
        node.addChildNode(panelNode)

        // Widget count indicators (small dots on the panel)
        for w in 0..<min(widgetCount, 6) {
            let dotGeo = SCNSphere(radius: 0.02)
            let dotMat = SCNMaterial()
            dotMat.diffuse.contents = NSColor.white.withAlphaComponent(0.8)
            dotMat.emission.contents = NSColor.white
            dotMat.emission.intensity = 0.4
            dotGeo.materials = [dotMat]
            let dotNode = SCNNode(geometry: dotGeo)
            let col = w % 3
            let row = w / 3
            dotNode.position = SCNVector3(Float(col) * 0.08 - 0.08, Float(row) * 0.08 - 0.04, 0.02)
            node.addChildNode(dotNode)
        }

        // Title label
        let label = buildLabel(String(report.name.prefix(12)),
                              color: NSColor.white.withAlphaComponent(0.7),
                              fontSize: 0.03)
        label.position = SCNVector3(0, 0.2, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        // Position in semicircle
        let angle = Float(index) * (Float.pi / Float(max(total - 1, 1))) - Float.pi / 2
        node.position = SCNVector3(cos(angle) * 1.6, sin(angle) * 0.3 + 0.2, sin(angle) * 0.3)

        return node
    }

    private static func buildForecastNode(forecast: TrendForecast, index: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "forecast_\(forecast.id)"

        // Trend arrow
        let arrowGeo = SCNCylinder(radius: 0.015, height: 0.6)
        let arrowMat = SCNMaterial()
        arrowMat.diffuse.contents = NSColor(hex: forecast.confidenceColorHex).withAlphaComponent(0.7)
        arrowMat.emission.contents = NSColor(hex: forecast.confidenceColorHex)
        arrowMat.emission.intensity = 0.3
        arrowGeo.materials = [arrowMat]
        let arrowNode = SCNNode(geometry: arrowGeo)
        arrowNode.eulerAngles.z = CGFloat.pi / 2
        node.addChildNode(arrowNode)

        // Confidence indicator (sphere size = confidence)
        let confRadius = CGFloat(forecast.confidence) * 0.1 + 0.05
        let confGeo = SCNSphere(radius: confRadius)
        let confMat = SCNMaterial()
        confMat.diffuse.contents = NSColor(hex: forecast.confidenceColorHex).withAlphaComponent(0.5)
        confMat.emission.contents = NSColor(hex: forecast.confidenceColorHex)
        confMat.emission.intensity = 0.4
        confGeo.materials = [confMat]
        let confNode = SCNNode(geometry: confGeo)
        confNode.position = SCNVector3(0.35, 0, 0)
        node.addChildNode(confNode)

        // Metric label
        let label = buildLabel(forecast.metric.displayName,
                              color: NSColor.white.withAlphaComponent(0.6),
                              fontSize: 0.03)
        label.position = SCNVector3(-0.35, 0.1, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        node.addChildNode(label)

        return node
    }

    private static func buildOptimizationRing(tips: [CostOptimizationTip]) -> SCNNode {
        let ring = SCNNode()
        ring.name = "optimizationRing"

        for (i, tip) in tips.enumerated() {
            let angle = Float(i) * (2 * Float.pi / Float(tips.count))
            let radius: Float = 0.9

            // Savings bar height proportional to savings amount
            let barHeight = CGFloat(min(tip.estimatedSavings, 20)) * 0.04 + 0.05
            let barGeo = SCNCylinder(radius: 0.03, height: barHeight)
            let barMat = SCNMaterial()
            barMat.diffuse.contents = NSColor(hex: tip.impact.colorHex).withAlphaComponent(0.7)
            barMat.emission.contents = NSColor(hex: tip.impact.colorHex)
            barMat.emission.intensity = 0.3
            barGeo.materials = [barMat]
            let barNode = SCNNode(geometry: barGeo)
            barNode.position = SCNVector3(cos(angle) * radius, Float(barHeight / 2), sin(angle) * radius)
            ring.addChildNode(barNode)
        }

        let ringRotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 45)
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
