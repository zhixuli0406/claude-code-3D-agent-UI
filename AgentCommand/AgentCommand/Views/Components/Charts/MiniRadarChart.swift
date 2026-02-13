import SwiftUI

// MARK: - Mini Radar Chart for Overlay Panels

/// A compact radar/spider chart for multi-dimensional data visualization
struct MiniRadarChart: View {
    let dimensions: [RadarChartDimension]
    var accentColor: Color = Color(hex: "#FF5722")
    var chartSize: CGFloat = 80
    var gridLevels: Int = 3
    var showLabels: Bool = true

    var body: some View {
        ZStack {
            // Grid rings
            ForEach(1...gridLevels, id: \.self) { level in
                radarPolygon(scale: CGFloat(level) / CGFloat(gridLevels))
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }

            // Axis lines
            ForEach(0..<dimensions.count, id: \.self) { index in
                axisLine(index: index)
            }

            // Data fill
            if dimensions.count >= 3 {
                dataPolygon
                    .fill(accentColor.opacity(0.15))
                dataPolygon
                    .stroke(accentColor.opacity(0.7), lineWidth: 1.5)
            }

            // Data dots
            ForEach(Array(dimensions.enumerated()), id: \.element.id) { index, dim in
                let point = dataPoint(index: index, value: dim.value)
                Circle()
                    .fill(accentColor)
                    .frame(width: 4, height: 4)
                    .position(point)
            }

            // Labels
            if showLabels {
                ForEach(Array(dimensions.enumerated()), id: \.element.id) { index, dim in
                    let labelPos = labelPosition(index: index)
                    VStack(spacing: 0) {
                        Text(dim.shortLabel)
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(Int(dim.value * 100))")
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor.opacity(0.8))
                    }
                    .position(labelPos)
                }
            }
        }
        .frame(width: chartSize, height: chartSize)
    }

    private func angle(for index: Int) -> CGFloat {
        CGFloat(index) / CGFloat(dimensions.count) * .pi * 2 - .pi / 2
    }

    private func point(index: Int, scale: CGFloat) -> CGPoint {
        let radius = chartSize / 2 * 0.7 * scale
        let a = angle(for: index)
        return CGPoint(
            x: chartSize / 2 + radius * cos(a),
            y: chartSize / 2 + radius * sin(a)
        )
    }

    private func dataPoint(index: Int, value: Double) -> CGPoint {
        point(index: index, scale: CGFloat(value))
    }

    private func labelPosition(index: Int) -> CGPoint {
        let radius = chartSize / 2 * 0.95
        let a = angle(for: index)
        return CGPoint(
            x: chartSize / 2 + radius * cos(a),
            y: chartSize / 2 + radius * sin(a)
        )
    }

    private func radarPolygon(scale: CGFloat) -> Path {
        Path { path in
            guard dimensions.count >= 3 else { return }
            let first = point(index: 0, scale: scale)
            path.move(to: first)
            for i in 1..<dimensions.count {
                path.addLine(to: point(index: i, scale: scale))
            }
            path.closeSubpath()
        }
    }

    private var dataPolygon: Path {
        Path { path in
            guard dimensions.count >= 3 else { return }
            let first = dataPoint(index: 0, value: dimensions[0].value)
            path.move(to: first)
            for i in 1..<dimensions.count {
                path.addLine(to: dataPoint(index: i, value: dimensions[i].value))
            }
            path.closeSubpath()
        }
    }

    private func axisLine(index: Int) -> some View {
        Path { path in
            let center = CGPoint(x: chartSize / 2, y: chartSize / 2)
            let end = point(index: index, scale: 1.0)
            path.move(to: center)
            path.addLine(to: end)
        }
        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
    }
}

// MARK: - Data Model

struct RadarChartDimension: Identifiable {
    let id = UUID()
    var label: String
    var shortLabel: String
    var value: Double // 0.0 - 1.0

    init(label: String, shortLabel: String? = nil, value: Double) {
        self.label = label
        self.shortLabel = shortLabel ?? String(label.prefix(3)).uppercased()
        self.value = min(1.0, max(0, value))
    }
}
