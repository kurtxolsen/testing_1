import SwiftUI

@main
struct AQEFieldWatchApp: App {
    @State private var link = PhoneLink()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(link)
                .tint(AQETheme.coral)
        }
    }
}

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchKnockView()
            WatchStatsView()
        }
        .tabViewStyle(.verticalPage)
    }
}
