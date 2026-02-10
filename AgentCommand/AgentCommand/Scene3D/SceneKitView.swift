import SwiftUI
import SceneKit

struct SceneKitView: NSViewRepresentable {
    let sceneManager: ThemeableScene
    var backgroundColor: NSColor = NSColor(hex: "#0A0A1A")
    var onAgentSelected: ((UUID) -> Void)?

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = sceneManager.scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = backgroundColor
        scnView.delegate = context.coordinator
        scnView.isPlaying = true
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60

        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(SceneClickHandler.handleClick(_:))
        )
        scnView.addGestureRecognizer(clickGesture)
        context.coordinator.scnView = scnView

        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.backgroundColor = backgroundColor
    }

    func makeCoordinator() -> SceneClickHandler {
        SceneClickHandler(sceneCoordinator: SceneCoordinator(onAgentSelected: onAgentSelected))
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

    // Forward delegate calls
    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        sceneCoordinator.renderer(renderer, updateAtTime: time)
    }
}
