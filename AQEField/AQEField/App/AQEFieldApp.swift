import SwiftUI

@main
struct AQEFieldApp: App {
    @State private var store = AppStore()
    @State private var location = LocationService()
    @State private var weather = WeatherService()
    @State private var sync = CloudSync()
    @State private var watch = WatchLink.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(location)
                .environment(weather)
                .environment(sync)
                .environment(watch)
                .tint(AQETheme.coral)
                .task {
                    location.requestPermission()
                    location.onTrailFix = { [weak store] coordinate in
                        store?.recordTrailPoint(coordinate)
                    }
                    // A wrist knock takes the phone's current GPS fix.
                    watch.onKnock = { [weak store, weak location, weak watch] outcome in
                        guard let store else { return }
                        store.logKnock(outcome,
                                       latitude: location?.lastCoordinate?.latitude,
                                       longitude: location?.lastCoordinate?.longitude,
                                       address: location?.lastAddress)
                        watch?.sendTodayStats(store.todayStats, goals: store.goals)
                    }
                    watch.sendTodayStats(store.todayStats, goals: store.goals)
                    await weather.refresh(coordinate: location.lastCoordinate)
                    await sync.syncNow(store: store)
                }
        }
    }
}
