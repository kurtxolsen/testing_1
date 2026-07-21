import SwiftUI

/// Team leaderboard. When signed in to Cloud Sync it ranks every rep on the
/// Supabase project by today's numbers; offline (or signed out) it falls
/// back to your own local stats so the screen always works.
struct TeamView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSync.self) private var sync
    @State private var teamRows: [CloudSync.TeamMemberStats] = []
    @State private var isLoading = false

    private var rows: [CloudSync.TeamMemberStats] {
        if !teamRows.isEmpty { return teamRows }
        // Local fallback: just you.
        let stats = store.todayStats
        var me = CloudSync.TeamMemberStats(
            id: sync.config.userID ?? "me",
            name: store.profile.name.isEmpty ? "You" : store.profile.name)
        me.knocks = stats.knocks
        me.leads = stats.leads
        me.signed = stats.contractsSigned
        return [me]
    }

    var body: some View {
        List {
            Section("Today's Leaderboard") {
                if isLoading && teamRows.isEmpty {
                    ProgressView()
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 12) {
                        Text("#\(index + 1)")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(index == 0 ? AQETheme.coral : .secondary)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name + (row.id == sync.config.userID ? " (you)" : ""))
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
                let teamKnocks = rows.reduce(0) { $0 + $1.knocks }
                let goal = store.goals.knocks * max(rows.count, 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(teamKnocks) / \(goal) knocks")
                        .font(.headline)
                    ProgressView(value: Double(min(teamKnocks, goal)), total: Double(max(goal, 1)))
                        .tint(AQETheme.coral)
                }
                .padding(.vertical, 4)
            }
            if !sync.isSignedIn {
                Section {
                    Label("Sign in under More → Cloud Sync to see the whole team here.",
                          systemImage: "person.3.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Team")
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        guard sync.isSignedIn else { return }
        isLoading = true
        teamRows = await sync.fetchTeamToday()
        isLoading = false
    }
}
