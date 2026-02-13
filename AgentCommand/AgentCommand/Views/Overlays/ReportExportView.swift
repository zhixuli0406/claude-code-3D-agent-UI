import SwiftUI

// MARK: - M2: Report Export Detail View (Sheet)

struct ReportExportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var selectedExportFormat: ExportFormat = .json

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#E91E63").opacity(0.3))

            TabView(selection: $selectedTab) {
                templatesTab.tag(0)
                schedulesTab.tag(1)
                exportsTab.tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 700, minHeight: 520)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if appState.reportExportManager.templates.isEmpty {
                appState.reportExportManager.loadSampleData()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "doc.badge.arrow.up")
                .foregroundColor(Color(hex: "#E91E63"))
            Text(localization.localized(.reExportReports))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Picker("", selection: $selectedTab) {
                Text(localization.localized(.reTemplates)).tag(0)
                Text(localization.localized(.reSchedules)).tag(1)
                Text(localization.localized(.reExports)).tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Templates Tab

    private var templatesTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button(localization.localized(.reCreateTemplate)) {
                    appState.reportExportManager.createTemplate(
                        name: "Custom Report \(appState.reportExportManager.templates.count + 1)",
                        description: "Custom report template",
                        sections: [
                            ReportSection(type: .executiveSummary),
                            ReportSection(type: .tokenUsage),
                            ReportSection(type: .costAnalysis),
                        ]
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#E91E63"))
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.reportExportManager.templates.isEmpty {
                emptyState(localization.localized(.reNoTemplates), icon: "doc.text")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.reportExportManager.templates) { template in
                            templateCard(template)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func templateCard(_ template: ReportTemplate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Color(hex: "#E91E63"))
                Text(template.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { appState.reportExportManager.deleteTemplate(template.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.borderless)
            }

            if !template.description.isEmpty {
                Text(template.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 6) {
                ForEach(template.sections) { section in
                    Text(section.type.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "#E91E63"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#E91E63").opacity(0.1))
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                if template.includeCharts {
                    Label("Charts", systemImage: "chart.bar")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                if template.includeSummary {
                    Label("Summary", systemImage: "text.alignleft")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#E91E63").opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Schedules Tab

    private var schedulesTab: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button(localization.localized(.reScheduleReport)) {
                    if let templateId = appState.reportExportManager.templates.first?.id {
                        appState.reportExportManager.createSchedule(
                            name: "Schedule \(appState.reportExportManager.schedules.count + 1)",
                            templateId: templateId,
                            frequency: .weekly,
                            format: .json
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appState.reportExportManager.templates.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.reportExportManager.schedules.isEmpty {
                emptyState(localization.localized(.reNoSchedules), icon: "calendar")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.reportExportManager.schedules) { schedule in
                            scheduleCard(schedule)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func scheduleCard(_ schedule: ReportSchedule) -> some View {
        HStack(spacing: 8) {
            Image(systemName: schedule.isActive ? "calendar.badge.clock" : "calendar")
                .foregroundColor(Color(hex: schedule.isActive ? "#E91E63" : "#9E9E9E"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Text(schedule.frequency.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#E91E63"))
                    Text(schedule.exportFormat.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    if let nextRun = schedule.nextRunAt {
                        Text("Next: \(nextRun, style: .relative)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.isActive },
                set: { _ in appState.reportExportManager.toggleSchedule(schedule.id) }
            ))
            .toggleStyle(.switch)

            Button(action: { appState.reportExportManager.deleteSchedule(schedule.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Exports Tab

    private var exportsTab: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker(localization.localized(.reExportFormat), selection: $selectedExportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .frame(width: 160)

                Button(localization.localized(.reExportNow)) {
                    appState.reportExportManager.exportReport(
                        format: selectedExportFormat,
                        templateId: appState.reportExportManager.templates.first?.id
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#E91E63"))

                Spacer()

                Text("\(appState.reportExportManager.completedExports.count) completed")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if appState.reportExportManager.exportJobs.isEmpty {
                emptyState(localization.localized(.reNoExports), icon: "arrow.down.doc")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.reportExportManager.exportJobs) { job in
                            exportJobCard(job)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func exportJobCard(_ job: ExportJob) -> some View {
        HStack(spacing: 8) {
            Image(systemName: job.format.iconName)
                .foregroundColor(Color(hex: job.status.colorHex))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(job.format.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text(job.status.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: job.status.colorHex))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: job.status.colorHex).opacity(0.15))
                        .cornerRadius(4)
                }

                if job.status == .inProgress {
                    ProgressView(value: job.progress)
                        .tint(Color(hex: "#E91E63"))
                        .frame(maxWidth: 200)
                }

                HStack(spacing: 8) {
                    if let size = job.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Text(job.startedAt, style: .relative)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            if job.status == .inProgress {
                Button("Cancel") {
                    appState.reportExportManager.cancelExport(job.id)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#F44336"))
            }

            Button(action: { appState.reportExportManager.deleteExportJob(job.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Empty State

    private func emptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
