import SwiftUI

struct TimelineEventDot: View {
    let event: TimelineEvent
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: event.kind.icon)
                    .font(.system(size: 8))
                Circle()
                    .fill(Color(hex: event.kind.hexColor))
                    .frame(width: isSelected ? 10 : 7, height: isSelected ? 10 : 7)
            }
            .foregroundColor(Color(hex: event.kind.hexColor))
            .opacity(isSelected ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
        .help(event.title)
    }
}
