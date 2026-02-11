import SwiftUI
import SceneKit

struct SceneKitView: NSViewRepresentable {
    let sceneManager: ThemeableScene
    var backgroundColor: NSColor = NSColor(hex: "#0A0A1A")
    var onAgentSelected: ((UUID) -> Void)?
    var onAgentDoubleClicked: ((UUID) -> Void)?
    var onAgentRightClicked: ((UUID, CGPoint) -> Void)?
    var onAgentHovered: ((UUID?, CGPoint?) -> Void)?
    var isFirstPersonMode: Bool = false
    var firstPersonUpdateHandler: (() -> Void)?
    // Drag & Drop
    var onTaskDragHovered: ((UUID?) -> Void)?
    var onTaskDroppedOnAgent: ((UUID, String) -> Bool)?

    func makeNSView(context: Context) -> HoverTrackingSCNView {
        let scnView = HoverTrackingSCNView()
        scnView.scene = sceneManager.scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = backgroundColor
        scnView.delegate = context.coordinator
        scnView.isPlaying = true
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60

        // Single click gesture
        let clickGesture = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(SceneClickHandler.handleClick(_:))
        )
        scnView.addGestureRecognizer(clickGesture)

        // Double click gesture
        let doubleClickGesture = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(SceneClickHandler.handleDoubleClick(_:))
        )
        doubleClickGesture.numberOfClicksRequired = 2
        scnView.addGestureRecognizer(doubleClickGesture)

        // Single click should not fire when double click is recognized
        clickGesture.delaysPrimaryMouseButtonEvents = false

        context.coordinator.scnView = scnView
        sceneManager.scnView = scnView

        // Mouse hover tracking
        scnView.onMouseMoved = { [weak scnView] point in
            guard let view = scnView else { return }
            context.coordinator.sceneCoordinator.handleHover(at: point, in: view)
        }
        scnView.onMouseExited = {
            context.coordinator.sceneCoordinator.clearHover()
        }

        // Right-click tracking
        scnView.onRightMouseDown = { [weak scnView] point, screenPoint in
            guard let view = scnView else { return }
            if let agentId = context.coordinator.sceneCoordinator.handleRightClick(at: point, in: view) {
                context.coordinator.sceneCoordinator.onAgentRightClicked?(agentId, screenPoint)
            }
        }

        // Drag & Drop: task from sidebar onto 3D agent
        scnView.onDragHoveredAgent = { agentId in
            onTaskDragHovered?(agentId)
        }
        scnView.onTaskDropped = { agentId, payload in
            return onTaskDroppedOnAgent?(agentId, payload) ?? false
        }

        return scnView
    }

    func updateNSView(_ nsView: HoverTrackingSCNView, context: Context) {
        nsView.backgroundColor = backgroundColor
        nsView.allowsCameraControl = !isFirstPersonMode
        context.coordinator.sceneCoordinator.firstPersonUpdateHandler = firstPersonUpdateHandler
    }

    func makeCoordinator() -> SceneClickHandler {
        let coordinator = SceneCoordinator(onAgentSelected: onAgentSelected)
        coordinator.onAgentDoubleClicked = onAgentDoubleClicked
        coordinator.onAgentRightClicked = onAgentRightClicked
        coordinator.onAgentHovered = onAgentHovered
        coordinator.sceneManager = sceneManager
        coordinator.onInteractiveObjectHovered = { isOver in
            if isOver {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        return SceneClickHandler(sceneCoordinator: coordinator)
    }
}

/// Handles click gestures and delegates to SceneCoordinator
class SceneClickHandler: NSObject, SCNSceneRendererDelegate {
    let sceneCoordinator: SceneCoordinator
    weak var scnView: SCNView?

    init(sceneCoordinator: SceneCoordinator) {
        self.sceneCoordinator = sceneCoordinator
        super.init()
    }

    @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard let view = scnView else { return }
        let location = gesture.location(in: view)
        sceneCoordinator.handleClick(at: location, in: view)
    }

    @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        guard let view = scnView else { return }
        let location = gesture.location(in: view)
        sceneCoordinator.handleDoubleClick(at: location, in: view)
    }

    // Forward delegate calls
    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        sceneCoordinator.renderer(renderer, updateAtTime: time)
    }
}
