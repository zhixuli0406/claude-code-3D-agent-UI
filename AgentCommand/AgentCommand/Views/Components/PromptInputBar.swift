import SwiftUI

struct PromptInputBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var promptText = ""
    @State private var showConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            // LIVE mode indicator
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text(localization.localized(.live))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.1))
            .cornerRadius(4)

            // New team indicator
            HStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .font(.caption)
                Text(localization.localized(.newTeamAutoCreated))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(4)

            // Terminal icon
            Image(systemName: "terminal")
                .foregroundColor(Color(hex: "#00BCD4"))
                .font(.system(size: 14))

            // Text field
            TextField(localization.localized(.typeTaskPrompt), text: $promptText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .onSubmit {
                    submitTask()
                }

            // Send button
            Button(action: { submitTask() }) {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                    Text(localization.localized(.send))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(promptText.isEmpty ? Color.gray.opacity(0.3) : Color(hex: "#00BCD4"))
                )
            }
            .buttonStyle(.plain)
            .disabled(promptText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#0D1117").opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#00BCD4").opacity(0.3)),
            alignment: .top
        )
        .overlay(
            confirmationBanner
        )
    }

    @ViewBuilder
    private var confirmationBanner: some View {
        if showConfirmation {
            Text(localization.localized(.taskCreated))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#4CAF50"))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(hex: "#4CAF50").opacity(0.15))
                .cornerRadius(4)
                .offset(y: -30)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func submitTask() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.submitPromptWithNewTeam(title: trimmed)
        promptText = ""

        withAnimation(.easeInOut(duration: 0.3)) {
            showConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showConfirmation = false
            }
        }
    }
}
