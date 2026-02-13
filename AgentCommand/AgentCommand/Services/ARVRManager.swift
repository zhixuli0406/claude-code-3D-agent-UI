import Foundation
import Combine

// MARK: - J3: AR/VR Support Manager

@MainActor
class ARVRManager: ObservableObject {
    @Published var settings: ARVRSettings = ARVRSettings()
    @Published var spatialAudioSources: [SpatialAudioSource] = []
    @Published var isVisionOSAvailable: Bool = false
    @Published var isImmersiveMode: Bool = false

    init() {
        checkPlatformAvailability()
    }

    private func checkPlatformAvailability() {
        #if os(visionOS)
        isVisionOSAvailable = true
        settings.currentPlatform = .visionOS
        #else
        isVisionOSAvailable = false
        settings.currentPlatform = .macOS
        #endif
    }

    func toggleGestureControl() {
        settings.gestureControlEnabled.toggle()
    }

    func toggleSpatialAudio() {
        settings.spatialAudioEnabled.toggle()
        if !settings.spatialAudioEnabled {
            spatialAudioSources.removeAll()
        }
    }

    func toggleHandTracking() {
        settings.handTrackingEnabled.toggle()
    }

    func setImmersiveLevel(_ level: ImmersiveLevel) {
        settings.immersiveLevel = level
        isImmersiveMode = level == .fullSpace
    }

    func addSpatialAudioSource(agentId: UUID, position: SIMD3<Float>) {
        let source = SpatialAudioSource(
            id: UUID(),
            agentId: agentId,
            position: position,
            volume: 0.8,
            isActive: true
        )
        spatialAudioSources.append(source)
    }

    func removeSpatialAudioSource(agentId: UUID) {
        spatialAudioSources.removeAll { $0.agentId == agentId }
    }

    func updateAudioSourcePosition(agentId: UUID, position: SIMD3<Float>) {
        if let idx = spatialAudioSources.firstIndex(where: { $0.agentId == agentId }) {
            spatialAudioSources[idx].position = position
        }
    }

    func togglePassthrough() {
        settings.passthrough.toggle()
    }
}
