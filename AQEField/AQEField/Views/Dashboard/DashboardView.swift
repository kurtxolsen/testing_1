import SwiftUI

/// Today's command center: weather header, live stat cards, goal rings,
/// quick actions, recent activity.
struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(WeatherService.self) private var weather
    @Environment(LocationService.self) private var location
    @Binding var selectedTab: AppTab
    @State private var showNewLead = false
    @State private var showFieldBible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    StatCardsView(stats: store.todayStats,
                                  streak: store.streakDays,
                                  estimatedValue: store.todayEstimatedValue)
                    GoalRingsView(stats: store.todayStats, goals: store.goals)
                    quickActions
                    recentActivity
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(AQETheme.screenBackground)
            .navigationBarHidden(true)
            .refreshable {
                await weather.refresh(coordinate: location.lastCoordinate)
            }
        }
        .sheet(isPresented: $showNewLead) { NewLeadSheet() }
        .sheet(isPresented: $showFieldBible) { FieldBibleView() }
    }

    // MARK: - Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: return "Good morning"
        case ..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(AQETheme.navy)
                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let summary = weather.summary {
                HStack(spacing: 6) {
                    Image(systemName: weather.conditionSymbol)
                    Text(summary)
                }
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AQETheme.navy, in: Capsule())
                .foregroundStyle(.white)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.title3.weight(.bold))
                .foregroundStyle(AQETheme.navy)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickAction("Log Knock", icon: "hand.raised.fingers.spread.fill", color: AQETheme.coral) {
                    selectedTab = .knock
                }
                quickAction("Map", icon: "map.fill", color: AQETheme.navy) {
                    selectedTab = .map
                }
                quickAction("New Lead", icon: "star.fill", color: AQETheme.statusGreen) {
                    showNewLead = true
                }
                quickAction("Follow Up", icon: "clock.arrow.circlepath", color: AQETheme.statusOrange) {
                    selectedTab = .reports
                }
            }
            quickAction("Field Bible", icon: "book.fill", color: AQETheme.navyLight) {
                showFieldBible = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickAction(_ title: String, icon: String, color: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.bigButton)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(height: 68)
            .background(color, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: - Recent activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Activity")
                .font(.title3.weight(.bold))
                .foregroundStyle(AQETheme.navy)
            if store.todayEvents.isEmpty {
                Text("No doors yet. Hit the Knock tab and get after it. 👊")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(AQETheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 0) {
                    ForEach(store.todayEvents.suffix(8).reversed()) { event in
                        ActivityRow(event: event)
                        Divider().padding(.leading, 52)
                    }
                }
                .background(AQETheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActivityRow: View {
    let event: KnockEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.outcome.icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(event.outcome.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(event.outcome.rawValue)
                    .font(.headline)
                if let address = event.address, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
