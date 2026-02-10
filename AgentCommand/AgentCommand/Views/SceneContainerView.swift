import SwiftUI

struct SceneContainerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 3D Scene
            SceneKitView(
                sceneManager: appState.sceneManager,
                backgroundColor: appState.sceneManager.sceneBackgroundColor,
                onAgentSelected: { agentId in
                    appState.selectAgent(agentId)
                }
            )

            // Top-left: agent status legend
            VStack(alignment: .leading) {
                StatusBadgeOverlay(
                    agents: appState.agents,
                    selectedAgentId: appState.selectedAgentId
                )
                .allowsHitTesting(false)

                Spacer()
            }

            // Top-center: progress HUD
            VStack {
                HStack {
                    Spacer()
                    ProgressOverlay(
                        tasks: appState.tasks,
                        isSimulationRunning: appState.isSimulationRunning
                    )
                    .allowsHitTesting(false)
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 8)
        }
    }
}
