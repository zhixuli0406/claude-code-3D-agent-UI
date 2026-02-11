import SwiftUI
import SceneKit

/// Picture-in-Picture secondary camera view sharing the same SCNScene
struct PiPSceneView: NSViewRepresentable {
    let scene: SCNScene
    let cameraPosition: SCNVector3
    let lookAt: SCNVector3
    let fov: CGFloat
    var onTap: (() -> Void)?

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 30

        // Create a dedicated camera node for PiP
        let pipCamera = SCNNode()
        pipCamera.camera = SCNCamera()
        pipCamera.camera?.fieldOfView = fov
        pipCamera.camera?.zNear = 0.1
        pipCamera.camera?.zFar = 100
        pipCamera.position = cameraPosition
        pipCamera.look(at: lookAt)
        pipCamera.name = "pipCamera"
        scene.rootNode.addChildNode(pipCamera)
        view.pointOfView = pipCamera

        // Click gesture for swap
        let click = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(PiPCoordinator.handleClick)
        )
        view.addGestureRecognizer(click)

        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        if let pipCam = scene.rootNode.childNode(withName: "pipCamera", recursively: false) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            pipCam.position = cameraPosition
            pipCam.look(at: lookAt)
            pipCam.camera?.fieldOfView = fov
            SCNTransaction.commit()
            nsView.pointOfView = pipCam
        }
    }

    func makeCoordinator() -> PiPCoordinator {
        PiPCoordinator(onTap: onTap)
    }
}

class PiPCoordinator: NSObject {
    let onTap: (() -> Void)?

    init(onTap: (() -> Void)?) {
        self.onTap = onTap
        super.init()
    }

    @objc func handleClick() {
        onTap?()
    }
}
