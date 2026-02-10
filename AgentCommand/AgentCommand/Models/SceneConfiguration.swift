import Foundation

struct SceneConfiguration: Codable {
    var roomSize: RoomDimensions
    var commandDeskPosition: ScenePosition
    var workstationPositions: [WorkstationConfig]
    var cameraDefaults: CameraConfig
    var ambientLightIntensity: Float
    var accentColor: String
}

struct RoomDimensions: Codable {
    var width: Float
    var height: Float
    var depth: Float
}

struct WorkstationConfig: Codable, Identifiable {
    var id: String
    var position: ScenePosition
    var size: DeskSize
}

enum DeskSize: String, Codable {
    case large
    case medium
    case small

    var width: Float {
        switch self {
        case .large: return 2.0
        case .medium: return 1.4
        case .small: return 1.0
        }
    }

    var depth: Float {
        switch self {
        case .large: return 1.0
        case .medium: return 0.8
        case .small: return 0.6
        }
    }
}

struct CameraConfig: Codable {
    var position: ScenePosition
    var lookAtTarget: ScenePosition
    var fieldOfView: Float
}
