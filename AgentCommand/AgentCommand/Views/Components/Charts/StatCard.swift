import SwiftUI

// MARK: - Stat Card for Overlay Panels

/// A compact statistics card showing a single metric with optional trend indicator
struct MiniStatCard: View {
    var icon: String
    var label: String
    var value: String
    var color: Color
    var trend: StatTrend?
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(color.opacity(0.7))
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.iconName)
                            .font(.system(size: 6))
                        Text(trend.displayText)
                            .font(.system(size: 6, design: .monospaced))
                    }
                    .foregroundColor(Color(hex: trend.colorHex))
                }
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Stat Trend

struct StatTrend {
    var direction: TrendDirection
    var percentageChange: Double

    var iconName: String { direction.iconName }
    var colorHex: String { direction.colorHex }
    var displayText: String {
        let pct = Int(abs(percentageChange * 100))
        switch direction {
        case .improving: return "+\(pct)%"
        case .stable: return "~\(pct)%"
        case .declining: return "-\(pct)%"
        }
    }
}

// MARK: - Comparison Bar

/// A compact comparison bar showing two values side-by-side
struct ComparisonBar: View {
    var label: String
    var valueA: Double
    var valueB: Double
    var labelA: String = "A"
    var labelB: String = "B"
    var colorA: Color = Color(hex: "#2196F3")
    var colorB: Color = Color(hex: "#FF9800")
    var unit: String = ""

    private var maxVal: Double { max(abs(valueA), abs(valueB), 0.01) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                let delta = valueB - valueA
                let pct = valueA > 0 ? Int(delta / valueA * 100) : 0
                Text(pct >= 0 ? "+\(pct)%" : "\(pct)%")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(Color(hex: pct >= 0 ? "#4CAF50" : "#F44336"))
            }
            HStack(spacing: 4) {
                // Bar A
                HStack(spacing: 2) {
                    Text(labelA)
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundColor(colorA.opacity(0.6))
                        .frame(width: 10)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(colorA.opacity(0.7))
                            .frame(width: max(2, CGFloat(valueA / maxVal) * geo.size.width))
                    }
                    .frame(height: 5)
                }
                // Bar B
                HStack(spacing: 2) {
                    Text(labelB)
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundColor(colorB.opacity(0.6))
                        .frame(width: 10)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(colorB.opacity(0.7))
                            .frame(width: max(2, CGFloat(valueB / maxVal) * geo.size.width))
                    }
                    .frame(height: 5)
                }
            }
        }
    }
}

// MARK: - Progress Ring

/// A compact circular progress indicator
struct MiniProgressRing: View {
    var progress: Double // 0.0 - 1.0
    var color: Color
    var size: CGFloat = 24
    var lineWidth: CGFloat = 3
    var showLabel: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1.0, CGFloat(progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showLabel {
                Text("\(Int(progress * 100))")
                    .font(.system(size: size * 0.3, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .frame(width: size, height: size)
    }
}
