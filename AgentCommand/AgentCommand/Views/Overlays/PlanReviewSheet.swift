import SwiftUI

struct PlanReviewSheet: View {
    let data: PlanReviewData
    let onApprove: () -> Void
    let onReject: (String?) -> Void

    @EnvironmentObject var localization: LocalizationManager

    @State private var rejectionFeedback: String = ""
    @State private var showRejectionInput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    planContentView

                    if !data.allowedPrompts.isEmpty {
                        allowedPromptsView
                    }
                }
                .padding(.horizontal, 4)
            }

            if showRejectionInput {
                rejectionInputView
            }

            buttonsView
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 400, idealHeight: 560)
        .padding(24)
        .background(Color(hex: "#0D1117"))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundColor(Color(hex: "#9C27B0"))

            Text(localization.localized(.planReview))
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
    }

    // MARK: - Plan Content

    private var planContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.planContent)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .textSelection(.enabled)
                .lineSpacing(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    // MARK: - Allowed Prompts

    private var allowedPromptsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.localized(.planActions))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#9C27B0"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "#9C27B0").opacity(0.15))
                .cornerRadius(3)

            ForEach(data.allowedPrompts) { prompt in
                HStack(spacing: 8) {
                    Text(prompt.tool)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#00BCD4"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#00BCD4").opacity(0.1))
                        .cornerRadius(3)

                    Text(prompt.prompt)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.02))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    // MARK: - Rejection Input

    private var rejectionInputView: some View {
        TextField(localization.localized(.planRejectionFeedback), text: $rejectionFeedback)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12, design: .monospaced))
    }

    // MARK: - Buttons

    private var buttonsView: some View {
        HStack {
            Button(action: {
                if showRejectionInput {
                    let feedback = rejectionFeedback.isEmpty ? nil : rejectionFeedback
                    onReject(feedback)
                } else {
                    showRejectionInput = true
                }
            }) {
                Text(localization.localized(.rejectPlan))
                    .foregroundColor(Color(hex: "#F44336"))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onApprove) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text(localization.localized(.approvePlan))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "#9C27B0"))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
}
