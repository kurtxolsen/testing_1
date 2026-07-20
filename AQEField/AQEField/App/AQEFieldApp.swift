import SwiftUI

@main
struct AQEFieldApp: App {
    @State private var store = AppStore()
    @State private var location = LocationService()
    @State private var weather = WeatherService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(location)
                .environment(weather)
                .tint(AQETheme.coral)
                .task {
                    location.requestPermission()
                    location.onTrailFix = { [weak store] coordinate in
                        store?.recordTrailPoint(coordinate)
                    }
                    await weather.refresh(coordinate: location.lastCoordinate)
                }
        }
    }
}
