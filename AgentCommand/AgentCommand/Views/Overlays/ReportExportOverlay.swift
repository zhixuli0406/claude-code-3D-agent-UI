import SwiftUI

// MARK: - M2: Report Export Status Overlay (right-side floating panel)

struct ReportExportOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager

    private let panelWidth: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color(hex: "#E91E63").opacity(0.3))
            contentSection
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(hex: "#0A0A1A")).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#E91E63").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#E91E63"))
            Text(localization.localized(.reExportReports))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            if appState.reportExportManager.isExporting {
                Circle()
                    .fill(Color(hex: "#4CAF50"))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var contentSection: some View {
        VStack(spacing: 6) {
            let manager = appState.reportExportManager

            HStack {
                Text(localization.localized(.reTemplates))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(manager.templates.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#E91E63"))
            }

            HStack {
                Text(localization.localized(.reSchedules))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(manager.activeScheduleCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack {
                Text(localization.localized(.reExports))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(manager.completedExports.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4CAF50"))
            }

            // Recent export jobs
            ForEach(manager.exportJobs.prefix(3)) { job in
                exportJobRow(job)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func exportJobRow(_ job: ExportJob) -> some View {
        HStack(spacing: 4) {
            Image(systemName: job.format.iconName)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: job.status.colorHex))
            Text(job.format.displayName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer()
            if job.status == .inProgress {
                Text("\(job.progressPercentage)%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color(hex: "#2196F3"))
            } else {
                Text(job.status.displayName)
                    .font(.system(size: 8))
                    .foregroundColor(Color(hex: job.status.colorHex).opacity(0.7))
            }
        }
    }
}
