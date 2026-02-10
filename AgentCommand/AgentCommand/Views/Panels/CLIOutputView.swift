import SwiftUI

struct CLIOutputView: View {
    let entries: [CLIOutputEntry]
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(Color(hex: "#00BCD4"))
                Text(localization.localized(.cliOutput))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(entries.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(entries) { entry in
                            CLIOutputEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                }
                .onChange(of: entries.count) { _, _ in
                    if let last = entries.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color.black.opacity(0.3))
            .cornerRadius(4)
        }
    }
}

struct CLIOutputEntryRow: View {
    let entry: CLIOutputEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(icon)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 14)

            Text(entry.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .lineLimit(3)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch entry.kind {
        case .assistantThinking: return ">"
        case .toolInvocation:   return "$"
        case .toolOutput:       return "<"
        case .finalResult:      return "*"
        case .error:            return "!"
        case .systemInfo:       return "#"
        }
    }

    private var textColor: Color {
        switch entry.kind {
        case .assistantThinking: return Color(hex: "#FF9800")
        case .toolInvocation:   return Color(hex: "#00BCD4")
        case .toolOutput:       return Color.white.opacity(0.6)
        case .finalResult:      return Color(hex: "#4CAF50")
        case .error:            return Color(hex: "#F44336")
        case .systemInfo:       return Color.white.opacity(0.4)
        }
    }
}
