import SwiftUI

/// A 2D top-down mini-map overlay showing agent positions and fog of war
struct MiniMapOverlay: View {
    @EnvironmentObject var appState: AppState

    let onAgentTap: (UUID) -> Void

    private let mapSize: CGFloat = 200
    private let headerHeight: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            mapCanvas
        }
        .frame(width: mapSize + 16, height: mapSize + headerHeight + 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "map.fill")
                .font(.system(size: 10))
                .foregroundColor(.cyan)
            Text("MINI-MAP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            progressBadge
        }
        .padding(.horizontal, 8)
        .frame(height: headerHeight)
        .background(Color.black.opacity(0.6))
    }

    private var progressBadge: some View {
        let roomSize = appState.sceneConfig?.roomSize ?? RoomDimensions(width: 20, height: 5, depth: 15)
        let percentage = appState.explorationManager.fogRevealPercentage(
            theme: appState.currentTheme.rawValue,
            roomSize: roomSize
        )
        return Text("\(Int(percentage * 100))%")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.yellow)
    }

    // MARK: - Map Canvas

    private var mapCanvas: some View {
        Canvas { context, size in
            let region = currentRegion
            let drawSize = CGSize(width: size.width, height: size.height)

            // 1. Grid lines
            drawGrid(context: context, size: drawSize)

            // 2. Fog of war
            drawFog(context: context, size: drawSize, region: region)

            // 3. Discovered items
            drawDiscoveredItems(context: context, size: drawSize, region: region)

            // 4. Agent dots
            drawAgents(context: context, size: drawSize, region: region)
        }
        .frame(width: mapSize, height: mapSize)
        .padding(8)
        .contentShape(Rectangle())
        .onTapGesture { location in
            handleMapTap(at: location)
        }
    }

    // MARK: - Drawing

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 20
        var path = Path()
        for x in stride(from: CGFloat(0), through: size.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: CGFloat(0), through: size.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
    }

    private func drawFog(context: GraphicsContext, size: CGSize, region: MiniMapRegion) {
        let cellW = size.width / CGFloat(region.gridWidth)
        let cellH = size.height / CGFloat(region.gridDepth)
        let theme = appState.currentTheme.rawValue

        for x in 0..<region.gridWidth {
            for z in 0..<region.gridDepth {
                if !appState.explorationManager.isFogRevealed(gridX: x, gridZ: z, theme: theme) {
                    let rect = CGRect(
                        x: CGFloat(x) * cellW,
                        y: CGFloat(z) * cellH,
                        width: cellW + 0.5,  // slight overlap to avoid gaps
                        height: cellH + 0.5
                    )
                    context.fill(Path(rect), with: .color(.black.opacity(0.7)))
                }
            }
        }
    }

    private func drawDiscoveredItems(context: GraphicsContext, size: CGSize, region: MiniMapRegion) {
        let theme = appState.currentTheme.rawValue
        let items = appState.explorationManager.discoveredItems(for: theme)

        for item in items {
            let (nx, nz) = region.normalized(x: item.position.x, z: item.position.z)
            let point = CGPoint(x: nx * size.width, y: nz * size.height)

            let color: Color = item.type == .easterEgg ? .yellow : .cyan
            let diamond = Path { path in
                path.move(to: CGPoint(x: point.x, y: point.y - 4))
                path.addLine(to: CGPoint(x: point.x + 3, y: point.y))
                path.addLine(to: CGPoint(x: point.x, y: point.y + 4))
                path.addLine(to: CGPoint(x: point.x - 3, y: point.y))
                path.closeSubpath()
            }
            context.fill(diamond, with: .color(color.opacity(0.8)))
        }

        // Also draw undiscovered items in revealed fog areas as "?" markers
        let undiscovered = appState.explorationManager.undiscoveredItems(for: theme)
        for item in undiscovered {
            let (gx, gz) = region.gridCoordsFromScene(x: item.position.x, z: item.position.z)
            if appState.explorationManager.isFogRevealed(gridX: gx, gridZ: gz, theme: theme) {
                let (nx, nz) = region.normalized(x: item.position.x, z: item.position.z)
                let point = CGPoint(x: nx * size.width, y: nz * size.height)

                // Draw a small "?" indicator
                let questionRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: questionRect), with: .color(.white.opacity(0.3)))
                context.draw(
                    Text("?").font(.system(size: 7, weight: .bold)),
                    at: point
                )
            }
        }
    }

    private func drawAgents(context: GraphicsContext, size: CGSize, region: MiniMapRegion) {
        for agent in appState.agents {
            let (nx, nz) = region.normalized(x: agent.position.x, z: agent.position.z)
            let point = CGPoint(x: nx * size.width, y: nz * size.height)
            let dotSize: CGFloat = agent.isMainAgent ? 10 : 7

            // Agent dot
            let dotRect = CGRect(
                x: point.x - dotSize / 2,
                y: point.y - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(
                Path(ellipseIn: dotRect),
                with: .color(Color(nsColor: NSColor(hex: agent.status.hexColor)))
            )

            // Border
            context.stroke(
                Path(ellipseIn: dotRect),
                with: .color(.white.opacity(0.6)),
                lineWidth: 0.8
            )

            // Star for commanders
            if agent.isMainAgent {
                let starRect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(
                    starPath(in: starRect),
                    with: .color(.white.opacity(0.9))
                )
            }

            // Highlight selected agent
            if agent.id == appState.selectedAgentId {
                let highlightRect = CGRect(
                    x: point.x - dotSize / 2 - 2,
                    y: point.y - dotSize / 2 - 2,
                    width: dotSize + 4,
                    height: dotSize + 4
                )
                context.stroke(
                    Path(ellipseIn: highlightRect),
                    with: .color(.white),
                    lineWidth: 1.5
                )
            }
        }
    }

    private func starPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = rect.width / 2
        let innerRadius = outerRadius * 0.4
        var path = Path()

        for i in 0..<10 {
            let angle = (CGFloat(i) * .pi / 5) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Interaction

    private func handleMapTap(at location: CGPoint) {
        let region = currentRegion
        // Convert tap location to normalized coords
        let nx = Float(location.x / mapSize)
        let nz = Float(location.y / mapSize)
        // Convert to world coords
        let worldX = nx * region.width - region.width / 2
        let worldZ = nz * region.depth - region.depth / 2

        // Find nearest agent within tap radius
        var closestAgent: Agent?
        var closestDist: Float = Float.greatestFiniteMagnitude
        let tapRadius: Float = 2.0

        for agent in appState.agents {
            let dx = agent.position.x - worldX
            let dz = agent.position.z - worldZ
            let dist = sqrt(dx * dx + dz * dz)
            if dist < tapRadius && dist < closestDist {
                closestDist = dist
                closestAgent = agent
            }
        }

        if let agent = closestAgent {
            onAgentTap(agent.id)
        }
    }

    // MARK: - Helpers

    private var currentRegion: MiniMapRegion {
        let roomSize = appState.sceneConfig?.roomSize ?? RoomDimensions(width: 20, height: 5, depth: 15)
        return MiniMapRegion(width: roomSize.width, depth: roomSize.depth)
    }
}
