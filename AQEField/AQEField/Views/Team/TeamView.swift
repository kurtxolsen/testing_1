import SwiftUI

/// Team leaderboard scaffold. Today it ranks you against your own daily
/// goals; the row model and layout are Supabase-ready, so teammates appear
/// here the moment sync lands — no UI rework.
struct TeamView: View {
    @Environment(AppStore.self) private var store

    private struct LeaderboardRow: Identifiable {
        let id: String
        let name: String
        let knocks: Int
        let leads: Int
        let signed: Int
        let isMe: Bool
    }

    private var rows: [LeaderboardRow] {
        let stats = store.todayStats
        let name = store.profile.name.isEmpty ? "You" : store.profile.name
        return [LeaderboardRow(id: "me", name: name, knocks: stats.knocks,
                               leads: stats.leads, signed: stats.contractsSigned, isMe: true)]
    }

    var body: some View {
        List {
            Section("Today's Leaderboard") {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 12) {
                        Text("#\(index + 1)")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(index == 0 ? AQETheme.coral : .secondary)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name + (row.isMe ? " (you)" : ""))
                                .font(.headline)
                            Text("\(row.knocks) knocks · \(row.leads) leads · \(row.signed) signed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("Team Goal") {
                let stats = store.todayStats
                let goal = store.goals.knocks
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(stats.knocks) / \(goal) knocks")
                        .font(.headline)
                    ProgressView(value: Double(min(stats.knocks, goal)), total: Double(goal))
                        .tint(AQETheme.coral)
                }
                .padding(.vertical, 4)
            }
            Section {
                Label("Teammates appear here once Supabase team sync is connected.",
                      systemImage: "person.3.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Team")
    }
}
