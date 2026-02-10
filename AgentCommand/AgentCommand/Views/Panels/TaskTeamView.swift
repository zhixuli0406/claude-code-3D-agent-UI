import SwiftUI

struct TaskTeamView: View {
    let team: [Agent]
    let leadAgentId: UUID?
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(Color(hex: "#00BCD4"))
                    .font(.caption)
                Text(localization.localized(.taskTeam))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(team.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ForEach(team) { agent in
                HStack(spacing: 8) {
                    Text(agent.role.emoji)
                        .font(.caption)

                    Text(agent.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if agent.id == leadAgentId {
                        Text(localization.localized(.teamLead))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#FFD700"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "#FFD700").opacity(0.15))
                            .cornerRadius(3)
                    }

                    Spacer()

                    // Status dot
                    Circle()
                        .fill(Color(hex: agent.status.hexColor))
                        .frame(width: 6, height: 6)

                    Text(agent.role.localizedName(localization))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
            }
        }
    }
}
