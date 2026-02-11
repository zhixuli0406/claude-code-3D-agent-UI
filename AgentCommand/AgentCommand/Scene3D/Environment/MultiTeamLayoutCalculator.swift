import Foundation

struct TeamLayout: Codable {
    let teamIndex: Int
    let commanderId: UUID
    let commandDeskPosition: ScenePosition
    let workstationPositions: [WorkstationConfig]
}

struct MultiTeamLayoutResult {
    let roomSize: RoomDimensions
    let teamLayouts: [TeamLayout]
    let camera: CameraConfig
    let agentPositions: [UUID: ScenePosition]
}

struct MultiTeamLayoutCalculator {

    // Per-team zone width
    private static let teamZoneWidth: Float = 10.0
    // Padding on room edges
    private static let roomPadding: Float = 6.0
    // Commander desk Z (front of zone)
    private static let commanderZ: Float = -2.0
    // Sub-agent row spacing
    private static let subAgentRowSpacing: Float = 3.0
    // Sub-agent column spacing
    private static let subAgentColSpacing: Float = 3.0
    // Max sub-agents per row
    private static let maxPerRow: Int = 2

    /// Compute layout for all teams derived from agents list
    static func calculateLayout(agents: [Agent]) -> MultiTeamLayoutResult {
        let commanders = agents.filter { $0.isMainAgent }
        let teamCount = max(commanders.count, 1)

        // Determine grid arrangement
        let cols = teamCount <= 4 ? teamCount : Int(ceil(sqrt(Double(teamCount))))
        let rows = Int(ceil(Double(teamCount) / Double(cols)))

        // Compute room dimensions
        let roomWidth = Float(cols) * teamZoneWidth + roomPadding
        let maxSubAgents = commanders.map { cmd in
            agents.filter { $0.parentAgentId == cmd.id }.count
        }.max() ?? 0
        let subAgentRows = Int(ceil(Double(maxSubAgents) / Double(maxPerRow)))
        let roomDepth = max(Float(subAgentRows) * subAgentRowSpacing + 8.0, 15.0) * Float(rows)
        let roomSize = RoomDimensions(width: roomWidth, height: 5.0, depth: roomDepth)

        var teamLayouts: [TeamLayout] = []
        var agentPositions: [UUID: ScenePosition] = [:]

        for (index, commander) in commanders.enumerated() {
            let col = index % cols
            let row = index / cols

            // Center X for this team's zone
            let totalWidth = Float(cols) * teamZoneWidth
            let zoneX = Float(col) * teamZoneWidth - totalWidth / 2.0 + teamZoneWidth / 2.0

            // Z offset for row
            let rowDepth = roomDepth / Float(rows)
            let zoneBaseZ = Float(row) * rowDepth

            // Commander position
            let cmdPos = ScenePosition(
                x: zoneX,
                y: 0,
                z: zoneBaseZ + commanderZ,
                rotation: 0
            )
            agentPositions[commander.id] = cmdPos

            // Sub-agents for this commander
            let subAgents = agents.filter { $0.parentAgentId == commander.id }
            var wsConfigs: [WorkstationConfig] = []

            for (si, sub) in subAgents.enumerated() {
                let subRow = si / maxPerRow
                let subCol = si % maxPerRow
                let subCount = min(subAgents.count - subRow * maxPerRow, maxPerRow)

                // Center sub-agents horizontally within zone
                let subTotalWidth = Float(subCount - 1) * subAgentColSpacing
                let subX = zoneX + Float(subCol) * subAgentColSpacing - subTotalWidth / 2.0
                let subZ = zoneBaseZ + 2.0 + Float(subRow) * subAgentRowSpacing

                // Slight rotation toward commander (negated since characters face Z+)
                let dx = zoneX - subX
                let rotation = -atan2(dx, 2.0) * 0.5

                let subPos = ScenePosition(x: subX, y: 0, z: subZ, rotation: rotation)
                agentPositions[sub.id] = subPos

                let size: DeskSize = (subRow == 0) ? .medium : .small
                wsConfigs.append(WorkstationConfig(
                    id: "team\(index)-ws\(si)",
                    position: subPos,
                    size: size
                ))
            }

            teamLayouts.append(TeamLayout(
                teamIndex: index,
                commanderId: commander.id,
                commandDeskPosition: cmdPos,
                workstationPositions: wsConfigs
            ))
        }

        let camera = computeCamera(teamCount: teamCount, cols: cols, rows: rows, roomSize: roomSize)

        return MultiTeamLayoutResult(
            roomSize: roomSize,
            teamLayouts: teamLayouts,
            camera: camera,
            agentPositions: agentPositions
        )
    }

    private static func computeCamera(teamCount: Int, cols: Int, rows: Int, roomSize: RoomDimensions) -> CameraConfig {
        let centerX: Float = 0
        let centerZ = roomSize.depth / 2.0 - 2.0

        switch teamCount {
        case 1:
            return CameraConfig(
                position: ScenePosition(x: centerX, y: 8, z: centerZ + 10, rotation: 0),
                lookAtTarget: ScenePosition(x: centerX, y: 1, z: centerZ - 4, rotation: 0),
                fieldOfView: 60
            )
        case 2:
            return CameraConfig(
                position: ScenePosition(x: centerX, y: 10, z: centerZ + 14, rotation: 0),
                lookAtTarget: ScenePosition(x: centerX, y: 0.5, z: centerZ - 4, rotation: 0),
                fieldOfView: 65
            )
        case 3...4:
            return CameraConfig(
                position: ScenePosition(x: centerX, y: 12, z: centerZ + 18, rotation: 0),
                lookAtTarget: ScenePosition(x: centerX, y: 0.5, z: centerZ - 4, rotation: 0),
                fieldOfView: 70
            )
        default:
            // 5+ teams
            let scale = Float(max(cols, rows))
            return CameraConfig(
                position: ScenePosition(x: centerX, y: 10 + scale * 2, z: centerZ + 14 + scale * 3, rotation: 0),
                lookAtTarget: ScenePosition(x: centerX, y: 0.5, z: centerZ - 2, rotation: 0),
                fieldOfView: min(75, 60 + Float(teamCount) * 2)
            )
        }
    }
}
