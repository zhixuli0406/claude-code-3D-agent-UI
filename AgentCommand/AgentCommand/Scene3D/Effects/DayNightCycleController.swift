import SceneKit

/// Controls scene lighting based on real-world time of day
class DayNightCycleController {
    private weak var scene: SCNScene?
    private var timer: Timer?

    deinit {
        timer?.invalidate()
    }

    func start(in scene: SCNScene) {
        self.scene = scene
        applyCurrentTimeOfDay()

        // Update every 5 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.applyCurrentTimeOfDay()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func applyCurrentTimeOfDay() {
        guard let scene = scene else { return }

        let hour = Calendar.current.component(.hour, from: Date())
        let (ambientIntensity, ambientColor, tintColor) = lightingForHour(hour)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 2.0

        for node in scene.rootNode.childNodes {
            if let light = node.light {
                switch light.type {
                case .ambient:
                    light.intensity = ambientIntensity
                    light.color = ambientColor
                case .directional, .omni:
                    light.color = tintColor
                default:
                    break
                }
            }
        }

        SCNTransaction.commit()
    }

    private func lightingForHour(_ hour: Int) -> (intensity: CGFloat, ambient: NSColor, tint: NSColor) {
        switch hour {
        case 6...8: // Dawn
            return (400, NSColor(hex: "#FFE0B2"), NSColor(hex: "#FF9800"))
        case 9...16: // Day
            return (600, NSColor(hex: "#ECEFF1"), NSColor(hex: "#FFFFFF"))
        case 17...19: // Dusk
            return (450, NSColor(hex: "#FFCCBC"), NSColor(hex: "#FF5722"))
        case 20...22: // Evening
            return (300, NSColor(hex: "#263238"), NSColor(hex: "#455A64"))
        default: // Night (23-5)
            return (200, NSColor(hex: "#1A237E"), NSColor(hex: "#283593"))
        }
    }
}
