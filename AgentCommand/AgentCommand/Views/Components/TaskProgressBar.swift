import SwiftUI

struct TaskProgressBar: View {
    let progress: Double
    var height: CGFloat = 6
    var showPercentage: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: height)

                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(progressGradient)
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: height)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: height)

            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var progressGradient: LinearGradient {
        if progress >= 1.0 {
            return LinearGradient(
                colors: [Color(hex: "#4CAF50"), Color(hex: "#8BC34A")],
                startPoint: .leading, endPoint: .trailing
            )
        } else if progress > 0.5 {
            return LinearGradient(
                colors: [Color(hex: "#FF9800"), Color(hex: "#FFC107")],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#00BCD4"), Color(hex: "#03A9F4")],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }
}
