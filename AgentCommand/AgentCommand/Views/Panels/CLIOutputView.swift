import SwiftUI
import AppKit

struct CLIOutputView: View {
    let entries: [CLIOutputEntry]
    @EnvironmentObject var localization: LocalizationManager
    @State private var showCopied = false

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

                if showCopied {
                    Text(localization.localized(.copied))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#4CAF50"))
                        .transition(.opacity)
                }

                Button(action: copyAll) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                        Text(localization.localized(.copyAll))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#00BCD4").opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(entries.isEmpty)

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

    private func copyAll() {
        let text = entries.map(\.text).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }
}

struct CLIOutputEntryRow: View {
    let entry: CLIOutputEntry
    @EnvironmentObject var localization: LocalizationManager

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
                .textSelection(.enabled)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
            }) {
                Label(localization.localized(.copyEntry), systemImage: "doc.on.doc")
            }
        }
    }

    private var icon: String {
        switch entry.kind {
        case .assistantThinking: return ">"
        case .toolInvocation:   return "$"
        case .toolOutput:       return "<"
        case .finalResult:      return "*"
        case .error:            return "!"
        case .systemInfo:       return "#"
        case .dangerousWarning: return "\u{26A0}"
        case .askQuestion:      return "?"
        case .planMode:         return "\u{1F4CB}"
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
        case .dangerousWarning: return Color(hex: "#FF9800")
        case .askQuestion:      return Color(hex: "#2196F3")
        case .planMode:         return Color(hex: "#9C27B0")
        }
    }
}
