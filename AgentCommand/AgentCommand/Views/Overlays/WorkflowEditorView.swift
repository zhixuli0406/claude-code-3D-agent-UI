import SwiftUI

// MARK: - L1: Workflow Editor View (Sheet)

struct WorkflowEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localization: LocalizationManager
    @State private var selectedTab = 0
    @State private var newWorkflowName = ""
    @State private var newWorkflowDesc = ""
    @State private var selectedTrigger: WorkflowTriggerType = .manual
    @State private var newStepName = ""
    @State private var newStepType: WorkflowStepType = .action
    @State private var newStepAction = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#7C4DFF").opacity(0.3))

            TabView(selection: $selectedTab) {
                workflowListTab.tag(0)
                templatesTab.tag(1)
                executionHistoryTab.tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 650, minHeight: 500)
        .background(Color(nsColor: NSColor(hex: "#0D1117")))
        .onAppear {
            appState.workflowManager.loadTemplates()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "gearshape.2.fill")
                .foregroundColor(Color(hex: "#7C4DFF"))
            Text(localization.localized(.wfWorkflowEngine))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()

            Picker("", selection: $selectedTab) {
                Text(localization.localized(.wfWorkflows)).tag(0)
                Text(localization.localized(.wfTemplates)).tag(1)
                Text(localization.localized(.wfHistory)).tag(2)
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

    // MARK: - Workflow List

    private var workflowListTab: some View {
        VStack(spacing: 12) {
            createWorkflowSection
            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.workflowManager.workflows.filter { !$0.isTemplate }) { workflow in
                        workflowCard(workflow)
                    }
                }
                .padding()
            }

            if appState.workflowManager.workflows.filter({ !$0.isTemplate }).isEmpty {
                emptyState(localization.localized(.wfNoWorkflows))
            }
        }
    }

    private var createWorkflowSection: some View {
        HStack(spacing: 8) {
            TextField(localization.localized(.wfWorkflowName), text: $newWorkflowName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            TextField(localization.localized(.wfWorkflowDesc), text: $newWorkflowDesc)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Picker("", selection: $selectedTrigger) {
                ForEach(WorkflowTriggerType.allCases) { trigger in
                    Label(trigger.displayName, systemImage: trigger.iconName).tag(trigger)
                }
            }
            .frame(width: 140)

            Button(localization.localized(.wfCreateWorkflow)) {
                guard !newWorkflowName.isEmpty else { return }
                _ = appState.workflowManager.createWorkflow(
                    name: newWorkflowName,
                    description: newWorkflowDesc,
                    triggerType: selectedTrigger
                )
                newWorkflowName = ""
                newWorkflowDesc = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#7C4DFF"))
            .disabled(newWorkflowName.isEmpty)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func workflowCard(_ workflow: Workflow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: workflow.status.iconName)
                    .foregroundColor(Color(hex: workflow.status.hexColor))
                Text(workflow.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(workflow.steps.count) steps")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Button(action: { appState.workflowManager.executeWorkflow(workflow.id) }) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .disabled(workflow.status == .running)

                Button(action: { appState.workflowManager.deleteWorkflow(workflow.id) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.borderless)
            }

            if !workflow.description.isEmpty {
                Text(workflow.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 4) {
                Image(systemName: workflow.trigger.type.iconName)
                    .font(.system(size: 9))
                Text(workflow.trigger.type.displayName)
                    .font(.system(size: 10))
                Spacer()
                Text("\(workflow.runCount) runs")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: workflow.status.hexColor).opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Templates

    private var templatesTab: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(appState.workflowManager.workflows.filter(\.isTemplate)) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(template.description)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Button(localization.localized(.wfUseTemplate)) {
                            let newWf = appState.workflowManager.createWorkflow(
                                name: template.name,
                                description: template.description,
                                triggerType: template.trigger.type
                            )
                            for step in template.steps {
                                appState.workflowManager.addStep(
                                    to: newWf.id,
                                    name: step.name,
                                    type: step.type,
                                    action: step.action
                                )
                            }
                            selectedTab = 0
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                }
            }
            .padding()
        }
    }

    // MARK: - Execution History

    private var executionHistoryTab: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(appState.workflowManager.executions) { exec in
                    HStack {
                        Image(systemName: exec.status.iconName)
                            .foregroundColor(Color(hex: exec.status.hexColor))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exec.workflowName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Text(exec.startedAt, style: .relative)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        Text("\(exec.currentStepIndex)/\(exec.totalSteps)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                }
            }
            .padding()
        }
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
