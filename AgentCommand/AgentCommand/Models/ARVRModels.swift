import Foundation

// MARK: - J3: AR/VR Support Models

enum ARVRPlatform: String, CaseIterable, Identifiable {
    case visionOS = "visionos"
    case macOS = "macos"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visionOS: return "Apple Vision Pro"
        case .macOS: return "macOS"
        }
    }

    var iconName: String {
        switch self {
        case .visionOS: return "visionpro"
        case .macOS: return "desktopcomputer"
        }
    }
}

enum GestureType: String, CaseIterable {
    case tap = "tap"
    case pinch = "pinch"
    case rotate = "rotate"
    case drag = "drag"

    var displayName: String {
        switch self {
        case .tap: return "Tap"
        case .pinch: return "Pinch"
        case .rotate: return "Rotate"
        case .drag: return "Drag"
        }
    }

    var hexColor: String {
        switch self {
        case .tap: return "#4CAF50"
        case .pinch: return "#2196F3"
        case .rotate: return "#FF9800"
        case .drag: return "#E91E63"
        }
    }
}

enum ImmersiveLevel: String, CaseIterable {
    case window = "window"
    case volume = "volume"
    case fullSpace = "full_space"

    var displayName: String {
        switch self {
        case .window: return "Window"
        case .volume: return "Volume"
        case .fullSpace: return "Full Space"
        }
    }

    var hexColor: String {
        switch self {
        case .window: return "#9E9E9E"
        case .volume: return "#42A5F5"
        case .fullSpace: return "#AB47BC"
        }
    }
}

struct SpatialAudioSource: Identifiable {
    let id: UUID
    var agentId: UUID?
    var position: SIMD3<Float>
    var volume: Float
    var isActive: Bool
}

struct ARVRSettings {
    var currentPlatform: ARVRPlatform = .macOS
    var immersiveLevel: ImmersiveLevel = .window
    var gestureControlEnabled: Bool = false
    var spatialAudioEnabled: Bool = false
    var handTrackingEnabled: Bool = false
    var passthrough: Bool = false
}
