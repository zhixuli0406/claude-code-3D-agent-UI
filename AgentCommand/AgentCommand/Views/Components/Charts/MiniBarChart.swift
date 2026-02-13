import SwiftUI

// MARK: - Mini Bar Chart for Overlay Panels

/// A compact horizontal or vertical bar chart suitable for overlay panels
struct MiniBarChart: View {
    let data: [BarChartDataPoint]
    var barColor: Color = Color(hex: "#9C27B0")
    var maxBarHeight: CGFloat = 40
    var barSpacing: CGFloat = 2
    var showLabels: Bool = true
    var orientation: BarOrientation = .vertical

    enum BarOrientation {
        case vertical
        case horizontal
    }

    private var maxValue: Double {
        data.map(\.value).max() ?? 1
    }

    var body: some View {
        switch orientation {
        case .vertical:
            verticalBars
        case .horizontal:
            horizontalBars
        }
    }

    private var verticalBars: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(data) { point in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(point.color ?? barColor)
                        .frame(
                            width: max(4, CGFloat(200 / max(1, data.count)) - barSpacing),
                            height: max(2, CGFloat(point.value / maxValue) * maxBarHeight)
                        )
                    if showLabels {
                        Text(point.label)
                            .font(.system(size: 6, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var horizontalBars: some View {
        VStack(spacing: barSpacing) {
            ForEach(data) { point in
                HStack(spacing: 4) {
                    if showLabels {
                        Text(point.label)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 50, alignment: .trailing)
                            .lineLimit(1)
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(point.color ?? barColor)
                            .frame(width: max(2, CGFloat(point.value / maxValue) * geo.size.width))
                    }
                    .frame(height: 8)
                    Text(point.formattedValue)
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Data Point

struct BarChartDataPoint: Identifiable {
    let id = UUID()
    var label: String
    var value: Double
    var color: Color?
    var formattedValue: String = ""

    init(label: String, value: Double, color: Color? = nil, formattedValue: String? = nil) {
        self.label = label
        self.value = value
        self.color = color
        self.formattedValue = formattedValue ?? String(format: "%.0f", value)
    }
}
