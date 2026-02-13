import SwiftUI

// MARK: - L2: Smart Scheduling Detail View (Sheet)

struct SmartSchedulingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var newTaskName = ""
    @State private var newTaskDesc = ""
    @State private var newTaskPriority: SchedulePriority = .medium
    @State private var newTaskTokens: String = "5000"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#00BFA5").opacity(0.3))

            TabView(selection: $selectedTab) {
                scheduleTab.tag(0)
                optimizationsTab.tag(1)
                timelineTab.tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 650, minHeight: 500)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            if appState.smartSchedulingManager.scheduledTasks.isEmpty {
                appState.smartSchedulingManager.loadSampleData()
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(Color(hex: "#00BFA5"))
            Text(localization.localized(.ssSmartScheduling))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Toggle(localization.localized(.ssAutoSchedule), isOn: Binding(
                get: { appState.smartSchedulingManager.isAutoScheduling },
                set: { $0 ? appState.smartSchedulingManager.enableAutoScheduling() : appState.smartSchedulingManager.disableAutoScheduling() }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.7))

            Picker("", selection: $selectedTab) {
                Text(localization.localized(.ssSchedule)).tag(0)
                Text(localization.localized(.ssOptimizations)).tag(1)
                Text(localization.localized(.ssTimeline)).tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var scheduleTab: some View {
        VStack(spacing: 12) {
            addTaskSection
            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(appState.smartSchedulingManager.scheduledTasks) { task in
                        taskCard(task)
                    }
                }
                .padding()
            }
        }
    }

    private var addTaskSection: some View {
        HStack(spacing: 8) {
            TextField(localization.localized(.ssTaskName), text: $newTaskName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)

            Picker("", selection: $newTaskPriority) {
                ForEach(SchedulePriority.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .frame(width: 100)

            TextField("Tokens", text: $newTaskTokens)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            Button(localization.localized(.ssAddTask)) {
                guard !newTaskName.isEmpty, let tokens = Int(newTaskTokens) else { return }
                appState.smartSchedulingManager.addTask(
                    name: newTaskName,
                    description: newTaskDesc,
                    priority: newTaskPriority,
                    estimatedTokens: tokens
                )
                newTaskName = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#00BFA5"))
            .disabled(newTaskName.isEmpty)

            Button(localization.localized(.ssOptimize)) {
                appState.smartSchedulingManager.optimizeSchedule()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func taskCard(_ task: ScheduledTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.status.iconName)
                .foregroundColor(Color(hex: task.status.hexColor))
            Circle()
                .fill(Color(hex: task.priority.hexColor))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Text("\(task.estimatedTokens) tokens")
                    if let suggested = task.suggestedTime {
                        Text(suggested, style: .time)
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            if task.isBatch {
                Text("Batch")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "#00BFA5"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#00BFA5").opacity(0.15))
                    .cornerRadius(4)
            }
            Button(action: { appState.smartSchedulingManager.markCompleted(task.id) }) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.borderless)
            .disabled(task.status == .completed)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
    }

    private var optimizationsTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(appState.smartSchedulingManager.optimizations.enumerated()), id: \.offset) { _, opt in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opt.reason)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Text("Estimated time saved: \(Int(opt.estimatedTimeSaved))s")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#00BFA5"))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                }
            }
            .padding()
        }
    }

    private var timelineTab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(appState.smartSchedulingManager.timeSlots) { slot in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: slot.utilizationPercent > 0.7 ? "#F44336" : (slot.utilizationPercent > 0.4 ? "#FF9800" : "#4CAF50")).opacity(0.6))
                            .frame(width: 30, height: CGFloat(slot.utilizationPercent) * 100 + 5)
                        Text("\(Calendar.current.component(.hour, from: slot.startTime))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
