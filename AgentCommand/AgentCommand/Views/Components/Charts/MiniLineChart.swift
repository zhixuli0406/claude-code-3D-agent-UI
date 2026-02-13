import SwiftUI

// MARK: - Mini Line Chart for Overlay Panels

/// A compact line/area chart for trend visualization in overlay panels
struct MiniLineChart: View {
    let dataPoints: [LineChartDataPoint]
    var lineColor: Color = Color(hex: "#4CAF50")
    var fillGradient: Bool = true
    var showDots: Bool = true
    var chartHeight: CGFloat = 40
    var dotRadius: CGFloat = 2.5

    private var maxValue: Double {
        dataPoints.map(\.value).max() ?? 1
    }

    private var minValue: Double {
        dataPoints.map(\.value).min() ?? 0
    }

    private var valueRange: Double {
        max(maxValue - minValue, 0.01)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = chartHeight

            ZStack(alignment: .bottomLeading) {
                // Fill area
                if fillGradient, dataPoints.count >= 2 {
                    areaPath(width: width, height: height)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0.02)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // Line path
                if dataPoints.count >= 2 {
                    linePath(width: width, height: height)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }

                // Data dots
                if showDots {
                    ForEach(Array(dataPoints.enumerated()), id: \.element.id) { index, point in
                        let x = xPosition(index: index, width: width)
                        let y = yPosition(value: point.value, height: height)
                        Circle()
                            .fill(point.color ?? lineColor)
                            .frame(width: dotRadius * 2, height: dotRadius * 2)
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .frame(height: chartHeight)
    }

    private func xPosition(index: Int, width: CGFloat) -> CGFloat {
        guard dataPoints.count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(dataPoints.count - 1) * width
    }

    private func yPosition(value: Double, height: CGFloat) -> CGFloat {
        let normalized = (value - minValue) / valueRange
        return height - CGFloat(normalized) * height
    }

    private func linePath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard dataPoints.count >= 2 else { return }
            let first = dataPoints[0]
            path.move(to: CGPoint(
                x: xPosition(index: 0, width: width),
                y: yPosition(value: first.value, height: height)
            ))
            for i in 1..<dataPoints.count {
                path.addLine(to: CGPoint(
                    x: xPosition(index: i, width: width),
                    y: yPosition(value: dataPoints[i].value, height: height)
                ))
            }
        }
    }

    private func areaPath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard dataPoints.count >= 2 else { return }
            path.move(to: CGPoint(x: xPosition(index: 0, width: width), y: height))
            path.addLine(to: CGPoint(
                x: xPosition(index: 0, width: width),
                y: yPosition(value: dataPoints[0].value, height: height)
            ))
            for i in 1..<dataPoints.count {
                path.addLine(to: CGPoint(
                    x: xPosition(index: i, width: width),
                    y: yPosition(value: dataPoints[i].value, height: height)
                ))
            }
            path.addLine(to: CGPoint(x: xPosition(index: dataPoints.count - 1, width: width), y: height))
            path.closeSubpath()
        }
    }
}

// MARK: - Data Point

struct LineChartDataPoint: Identifiable {
    let id = UUID()
    var label: String
    var value: Double
    var color: Color?

    init(label: String = "", value: Double, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
}
