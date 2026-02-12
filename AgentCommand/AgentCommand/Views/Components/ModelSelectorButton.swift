import SwiftUI

struct ModelSelectorButton: View {
    @Binding var selectedModel: ClaudeModel
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        Menu {
            ForEach(ClaudeModel.allCases.sorted(by: { $0.sortOrder > $1.sortOrder })) { model in
                Button(action: { selectedModel = model }) {
                    HStack {
                        Text(model.rawValue)
                        Text("— \(model.localizedDescription(localization))")
                            .foregroundColor(.secondary)
                        if model == selectedModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedModel.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: selectedModel.hexColor))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: selectedModel.hexColor).opacity(0.15))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: selectedModel.hexColor).opacity(0.3), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
