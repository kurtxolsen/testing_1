import SwiftUI

enum AppTab: Hashable {
    case dashboard, map, knock, reports, more
}

/// Bottom navigation + the global floating "+" action button.
struct RootView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var showQuickAdd = false
    @State private var showNewLead = false
    @State private var showQuickNote = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                DashboardView(selectedTab: $selectedTab)
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    .tag(AppTab.dashboard)
                MapTabView()
                    .tabItem { Label("Map", systemImage: "map.fill") }
                    .tag(AppTab.map)
                KnockView()
                    .tabItem { Label("Knock", systemImage: "hand.raised.fingers.spread.fill") }
                    .tag(AppTab.knock)
                ReportsView()
                    .tabItem { Label("Reports", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(AppTab.reports)
                MoreView()
                    .tabItem { Label("More", systemImage: "line.3.horizontal") }
                    .tag(AppTab.more)
            }

            FloatingActionButton {
                showQuickAdd = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 70)
        }
        .confirmationDialog("Quick Add", isPresented: $showQuickAdd, titleVisibility: .hidden) {
            Button("New Lead") { showNewLead = true }
            Button("Log Knock") { selectedTab = .knock }
            Button("Follow Up") { selectedTab = .reports }
            Button("Note") { showQuickNote = true }
        }
        .sheet(isPresented: $showNewLead) { NewLeadSheet() }
        .sheet(isPresented: $showQuickNote) { QuickNoteSheet() }
    }
}

struct FloatingActionButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(AQETheme.coral, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .accessibilityLabel("Quick add")
    }
}

/// Fast free-form note, GPS-tagged like everything else.
struct QuickNoteSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextField("What happened?", text: $text, axis: .vertical)
                .font(.title3)
                .lineLimit(4...10)
                .padding()
                .navigationTitle("Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.logKnock(.conversation,
                                           latitude: location.lastCoordinate?.latitude,
                                           longitude: location.lastCoordinate?.longitude,
                                           address: location.lastAddress,
                                           note: text)
                            dismiss()
                        }
                        .disabled(text.isEmpty)
                    }
                }
        }
        .presentationDetents([.medium])
    }
}
