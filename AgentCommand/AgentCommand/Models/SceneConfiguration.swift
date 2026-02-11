import Foundation

struct SceneConfiguration: Codable {
    var roomSize: RoomDimensions
    var commandDeskPosition: ScenePosition
    var workstationPositions: [WorkstationConfig]
    var teamLayouts: [TeamLayout]?
    var cameraDefaults: CameraConfig
    var ambientLightIntensity: Float
    var accentColor: String

    /// Build a configuration from multi-team layout result, preserving first team as the legacy commandDeskPosition
    static func fromMultiTeam(_ result: MultiTeamLayoutResult, intensity: Float = 500, accent: String = "#00BCD4") -> SceneConfiguration {
        let firstTeam = result.teamLayouts.first
        return SceneConfiguration(
            roomSize: result.roomSize,
            commandDeskPosition: firstTeam?.commandDeskPosition ?? ScenePosition(x: 0, y: 0, z: -2, rotation: 0),
            workstationPositions: firstTeam?.workstationPositions ?? [],
            teamLayouts: result.teamLayouts,
            cameraDefaults: result.camera,
            ambientLightIntensity: intensity,
            accentColor: accent
        )
    }
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
