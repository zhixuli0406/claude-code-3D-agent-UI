import SceneKit

/// Manages continuous ambient particles in the 3D scene
class AmbientParticleSystem {
    private var particleNodes: [SCNNode] = []
    private var containerNode: SCNNode?
    private var isRunning = false

    /// Start ambient particles for the given theme
    func start(in scene: SCNScene, theme: SceneTheme, dimensions: RoomDimensions) {
        stop()

        let container = SCNNode()
        container.name = "ambientParticles"

        let particles = ParticleEffectBuilder.buildAmbientParticles(theme: theme, dimensions: dimensions)
        for node in particles {
            container.addChildNode(node)
        }

        scene.rootNode.addChildNode(container)
        containerNode = container
        particleNodes = particles
        isRunning = true
    }

    /// Remove all ambient particles
    func stop() {
        guard isRunning else { return }
        containerNode?.removeFromParentNode()
        containerNode = nil
        particleNodes.removeAll()
        isRunning = false
    }
}
