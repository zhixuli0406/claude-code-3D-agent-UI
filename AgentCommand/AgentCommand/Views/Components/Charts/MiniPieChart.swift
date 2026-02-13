import SwiftUI

// MARK: - Mini Pie/Donut Chart for Overlay Panels

/// A compact donut chart for category distribution visualization
struct MiniPieChart: View {
    let slices: [PieSlice]
    var innerRadiusRatio: CGFloat = 0.55
    var chartSize: CGFloat = 60
    var showLegend: Bool = true

    private var total: Double {
        max(slices.reduce(0) { $0 + $1.value }, 0.01)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Donut chart
            ZStack {
                ForEach(Array(sliceAngles.enumerated()), id: \.offset) { index, angles in
                    PieSliceShape(startAngle: angles.start, endAngle: angles.end)
                        .fill(slices[index].color)
                    PieSliceShape(startAngle: angles.start, endAngle: angles.end)
                        .fill(slices[index].color.opacity(0.3))
                        .blur(radius: 1)
                }

                // Inner circle for donut effect
                Circle()
                    .fill(Color(hex: "#0A0A1A").opacity(0.95))
                    .frame(width: chartSize * innerRadiusRatio, height: chartSize * innerRadiusRatio)

                // Center label
                if let topSlice = slices.max(by: { $0.value < $1.value }) {
                    Text("\(Int(topSlice.value / total * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(topSlice.color)
                }
            }
            .frame(width: chartSize, height: chartSize)

            // Legend
            if showLegend {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(slices) { slice in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 5, height: 5)
                            Text(slice.label)
                                .font(.system(size: 7))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(slice.value / total * 100))%")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }
        }
    }

    private var sliceAngles: [(start: Angle, end: Angle)] {
        var angles: [(start: Angle, end: Angle)] = []
        var currentAngle = Angle.degrees(-90)
        for slice in slices {
            let sliceAngle = Angle.degrees(slice.value / total * 360)
            angles.append((start: currentAngle, end: currentAngle + sliceAngle))
            currentAngle = currentAngle + sliceAngle
        }
        return angles
    }
}

// MARK: - Pie Slice Shape

struct PieSliceShape: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Data Model

struct PieSlice: Identifiable {
    let id = UUID()
    var label: String
    var value: Double
    var color: Color

    init(label: String, value: Double, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }
}
