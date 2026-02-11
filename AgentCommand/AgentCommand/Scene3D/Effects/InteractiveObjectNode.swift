import SceneKit
import SpriteKit

/// Types of interactive objects that can be placed in the scene
enum InteractiveObjectType: String {
    case monitor
    case door
    case serverRack
    case whiteboard
}

/// A scene node that can be clicked to trigger an interaction effect.
/// Interactive objects have a highlight animation on hover and play
/// a visual feedback animation when clicked.
class InteractiveObjectNode: SCNNode {
    let objectType: InteractiveObjectType
    /// Optional associated agent ID (e.g. the monitor's owner)
    var associatedAgentId: UUID?
    /// Callback when the object is clicked
    var onInteraction: (() -> Void)?

    init(objectType: InteractiveObjectType) {
        self.objectType = objectType
        super.init()
        self.name = "interactive_\(objectType.rawValue)"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Hover Highlight

    func showHoverHighlight() {
        guard childNode(withName: "hoverGlow", recursively: false) == nil else { return }

        let glowNode = SCNNode()
        glowNode.name = "hoverGlow"

        // Use the bounding box to create a matching outline
        let (minBound, maxBound) = boundingBox
        let width = CGFloat(maxBound.x - minBound.x) + 0.1
        let height = CGFloat(maxBound.y - minBound.y) + 0.1
        let length = CGFloat(maxBound.z - minBound.z) + 0.1

        let box = SCNBox(width: width, height: height, length: length, chamferRadius: 0.02)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.clear
        material.emission.contents = NSColor(hex: "#00BCD4").withAlphaComponent(0.3)
        material.emission.intensity = 1.0
        material.isDoubleSided = true
        material.blendMode = .add
        material.transparency = 0.3
        box.materials = [material]

        glowNode.geometry = box
        let centerY = (minBound.y + maxBound.y) / 2
        glowNode.position = SCNVector3(0, centerY, 0)

        // Pulsing animation
        let pulseUp = SCNAction.customAction(duration: 0.8) { node, elapsed in
            let t = Float(elapsed) / 0.8
            let intensity = 0.6 + 0.4 * sin(t * Float.pi)
            node.geometry?.materials.first?.emission.intensity = CGFloat(intensity)
        }
        glowNode.runAction(.repeatForever(pulseUp), forKey: "hoverPulse")

        glowNode.opacity = 0
        addChildNode(glowNode)
        glowNode.runAction(.fadeIn(duration: 0.15))
    }

    func hideHoverHighlight() {
        guard let glow = childNode(withName: "hoverGlow", recursively: false) else { return }
        glow.runAction(.sequence([.fadeOut(duration: 0.15), .removeFromParentNode()]))
    }

    // MARK: - Click Interaction Animation

    func playInteractionEffect() {
        switch objectType {
        case .monitor:
            playMonitorInteraction()
        case .door:
            playDoorInteraction()
        case .serverRack:
            playServerRackInteraction()
        case .whiteboard:
            playWhiteboardInteraction()
        }
    }

    private func playMonitorInteraction() {
        // Flash the screen with a bright pulse
        guard let screenNode = childNode(withName: "screen", recursively: true) else {
            playGenericPulse()
            return
        }

        let originalEmission = screenNode.geometry?.materials.first?.emission.intensity ?? 0.5

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.15
        screenNode.geometry?.materials.first?.emission.intensity = 2.0
        SCNTransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            screenNode.geometry?.materials.first?.emission.intensity = originalEmission
            SCNTransaction.commit()
        }

        // Update screen content to show "Accessing..."
        if let material = screenNode.geometry?.materials.first,
           let skScene = material.diffuse.contents as? SKScene {
            if let statusLabel = skScene.childNode(withName: "statusLine") as? SKLabelNode {
                let originalText = statusLabel.text
                statusLabel.text = "> Accessing system..."
                statusLabel.fontColor = NSColor(hex: "#00BCD4")

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    statusLabel.text = originalText
                    statusLabel.fontColor = NSColor(hex: "#4CAF50")
                }
            }
        }
    }

    private func playDoorInteraction() {
        // Rotate door open, then close
        guard let doorPanel = childNode(withName: "doorPanel", recursively: true) else {
            playGenericPulse()
            return
        }

        let openDoor = SCNAction.rotateTo(x: 0, y: -CGFloat.pi / 2, z: 0, duration: 0.6)
        openDoor.timingMode = .easeInEaseOut
        let holdOpen = SCNAction.wait(duration: 1.5)
        let closeDoor = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.6)
        closeDoor.timingMode = .easeInEaseOut

        doorPanel.runAction(.sequence([openDoor, holdOpen, closeDoor]))
    }

    private func playServerRackInteraction() {
        // Blink LED lights rapidly
        enumerateChildNodes { node, _ in
            guard node.name == "ledLight" else { return }
            let originalColor = node.geometry?.materials.first?.emission.contents

            let blink = SCNAction.customAction(duration: 2.0) { node, elapsed in
                let on = Int(elapsed * 8) % 2 == 0
                node.geometry?.materials.first?.emission.intensity = on ? 1.5 : 0.2
            }
            let reset = SCNAction.run { node in
                node.geometry?.materials.first?.emission.intensity = 0.8
                node.geometry?.materials.first?.emission.contents = originalColor
            }
            node.runAction(.sequence([blink, reset]))
        }

        playGenericPulse()
    }

    private func playWhiteboardInteraction() {
        // Brief glow on the whiteboard surface
        guard let surface = childNode(withName: "whiteboardSurface", recursively: true) else {
            playGenericPulse()
            return
        }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        surface.geometry?.materials.first?.emission.contents = NSColor(hex: "#E3F2FD")
        surface.geometry?.materials.first?.emission.intensity = 0.8
        SCNTransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            surface.geometry?.materials.first?.emission.intensity = 0
            SCNTransaction.commit()
        }
    }

    private func playGenericPulse() {
        let scaleUp = SCNAction.scale(to: 1.05, duration: 0.15)
        scaleUp.timingMode = .easeOut
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.15)
        scaleDown.timingMode = .easeIn
        runAction(.sequence([scaleUp, scaleDown]))
    }
}

// MARK: - Interactive Object Builder

struct InteractiveObjectBuilder {

    /// Build a clickable monitor node that wraps the standard monitor
    static func buildInteractiveMonitor(palette: ThemeColorPalette, agentId: UUID? = nil) -> InteractiveObjectNode {
        let interactive = InteractiveObjectNode(objectType: .monitor)
        interactive.associatedAgentId = agentId

        // Build standard monitor inside
        let monitor = MonitorBuilder.build(palette: palette)
        interactive.addChildNode(monitor)

        return interactive
    }

    /// Build a clickable door with open/close animation
    static func buildInteractiveDoor(palette: ThemeColorPalette) -> InteractiveObjectNode {
        let interactive = InteractiveObjectNode(objectType: .door)

        // Door frame
        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        frameMaterial.metalness.contents = 0.4

        // Frame top
        let frameTop = SCNBox(width: 1.1, height: 0.08, length: 0.12, chamferRadius: 0)
        frameTop.materials = [frameMaterial]
        let frameTopNode = SCNNode(geometry: frameTop)
        frameTopNode.position = SCNVector3(0, 2.1, 0)
        interactive.addChildNode(frameTopNode)

        // Frame sides
        let frameSide = SCNBox(width: 0.08, height: 2.1, length: 0.12, chamferRadius: 0)
        frameSide.materials = [frameMaterial]
        let leftFrame = SCNNode(geometry: frameSide)
        leftFrame.position = SCNVector3(-0.54, 1.05, 0)
        interactive.addChildNode(leftFrame)

        let rightFrame = SCNNode(geometry: frameSide)
        rightFrame.position = SCNVector3(0.54, 1.05, 0)
        interactive.addChildNode(rightFrame)

        // Door panel (pivots on left edge)
        let doorMaterial = SCNMaterial()
        doorMaterial.diffuse.contents = NSColor(hex: palette.surfaceColor).blended(
            withFraction: 0.3, of: NSColor(hex: palette.accentColor)
        ) ?? NSColor(hex: palette.surfaceColor)
        doorMaterial.roughness.contents = 0.7

        let panel = SCNBox(width: 0.95, height: 2.0, length: 0.05, chamferRadius: 0.01)
        panel.materials = [doorMaterial]
        let panelNode = SCNNode(geometry: panel)
        panelNode.name = "doorPanel"
        // Pivot on left edge
        panelNode.pivot = SCNMatrix4MakeTranslation(-0.475, 0, 0)
        panelNode.position = SCNVector3(-0.475, 1.0, 0)
        interactive.addChildNode(panelNode)

        // Door handle
        let handleMaterial = SCNMaterial()
        handleMaterial.diffuse.contents = NSColor(hex: "#B0BEC5")
        handleMaterial.metalness.contents = 0.8
        let handle = SCNCylinder(radius: 0.02, height: 0.12)
        handle.materials = [handleMaterial]
        let handleNode = SCNNode(geometry: handle)
        handleNode.eulerAngles.z = CGFloat.pi / 2
        handleNode.position = SCNVector3(0.35, 0.95, 0.04)
        panelNode.addChildNode(handleNode)

        return interactive
    }

    /// Build a clickable server rack with blinking LEDs
    static func buildInteractiveServerRack(palette: ThemeColorPalette) -> InteractiveObjectNode {
        let interactive = InteractiveObjectNode(objectType: .serverRack)

        let rackMaterial = SCNMaterial()
        rackMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        rackMaterial.metalness.contents = 0.6

        // Rack body
        let body = SCNBox(width: 0.6, height: 1.8, length: 0.5, chamferRadius: 0.02)
        body.materials = [rackMaterial]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.9, 0)
        interactive.addChildNode(bodyNode)

        // Server units (3 shelves)
        let unitMaterial = SCNMaterial()
        unitMaterial.diffuse.contents = NSColor(hex: "#1A1A2E")
        unitMaterial.metalness.contents = 0.3

        for i in 0..<3 {
            let unit = SCNBox(width: 0.52, height: 0.3, length: 0.42, chamferRadius: 0)
            unit.materials = [unitMaterial]
            let unitNode = SCNNode(geometry: unit)
            unitNode.position = SCNVector3(0, 0.35 + Float(i) * 0.5, 0.02)
            bodyNode.addChildNode(unitNode)

            // LED indicators
            for j in 0..<3 {
                let ledColors: [NSColor] = [
                    NSColor(hex: "#4CAF50"),
                    NSColor(hex: "#FF9800"),
                    NSColor(hex: "#2196F3")
                ]
                let ledMaterial = SCNMaterial()
                ledMaterial.diffuse.contents = ledColors[j]
                ledMaterial.emission.contents = ledColors[j]
                ledMaterial.emission.intensity = 0.8

                let led = SCNSphere(radius: 0.015)
                led.materials = [ledMaterial]
                let ledNode = SCNNode(geometry: led)
                ledNode.name = "ledLight"
                ledNode.position = SCNVector3(-0.18 + Float(j) * 0.08, 0.1, 0.22)
                unitNode.addChildNode(ledNode)

                // Random blinking
                let blinkDelay = Double.random(in: 0.5...3.0)
                let blinkAction = SCNAction.sequence([
                    .wait(duration: blinkDelay),
                    .customAction(duration: 0.1) { node, _ in
                        node.geometry?.materials.first?.emission.intensity = 0.2
                    },
                    .wait(duration: 0.1),
                    .customAction(duration: 0.1) { node, _ in
                        node.geometry?.materials.first?.emission.intensity = 0.8
                    }
                ])
                ledNode.runAction(.repeatForever(blinkAction))
            }
        }

        return interactive
    }

    /// Build a clickable whiteboard
    static func buildInteractiveWhiteboard(palette: ThemeColorPalette) -> InteractiveObjectNode {
        let interactive = InteractiveObjectNode(objectType: .whiteboard)

        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = NSColor(hex: palette.structuralColor)
        frameMaterial.metalness.contents = 0.3

        // Frame
        let frame = SCNBox(width: 1.6, height: 1.1, length: 0.05, chamferRadius: 0.01)
        frame.materials = [frameMaterial]
        let frameNode = SCNNode(geometry: frame)
        frameNode.position = SCNVector3(0, 1.4, 0)
        interactive.addChildNode(frameNode)

        // Whiteboard surface
        let surfaceMaterial = SCNMaterial()
        surfaceMaterial.diffuse.contents = NSColor(hex: "#ECEFF1")
        surfaceMaterial.roughness.contents = 0.3
        let surface = SCNBox(width: 1.45, height: 0.95, length: 0.01, chamferRadius: 0)
        surface.materials = [surfaceMaterial]
        let surfaceNode = SCNNode(geometry: surface)
        surfaceNode.name = "whiteboardSurface"
        surfaceNode.position = SCNVector3(0, 0, 0.03)
        frameNode.addChildNode(surfaceNode)

        // Marker tray
        let tray = SCNBox(width: 1.2, height: 0.03, length: 0.06, chamferRadius: 0)
        tray.materials = [frameMaterial]
        let trayNode = SCNNode(geometry: tray)
        trayNode.position = SCNVector3(0, -0.52, 0.04)
        frameNode.addChildNode(trayNode)

        // Colored markers
        let markerColors = ["#F44336", "#2196F3", "#4CAF50"]
        for (i, colorHex) in markerColors.enumerated() {
            let markerMaterial = SCNMaterial()
            markerMaterial.diffuse.contents = NSColor(hex: colorHex)
            let marker = SCNCylinder(radius: 0.012, height: 0.1)
            marker.materials = [markerMaterial]
            let markerNode = SCNNode(geometry: marker)
            markerNode.eulerAngles.z = CGFloat.pi / 2
            markerNode.position = SCNVector3(-0.15 + Float(i) * 0.15, -0.50, 0.06)
            frameNode.addChildNode(markerNode)
        }

        return interactive
    }
}
