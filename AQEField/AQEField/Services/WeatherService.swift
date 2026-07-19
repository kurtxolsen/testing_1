import Foundation
import CoreLocation
import Observation

/// Current temperature + wind from Open-Meteo (free, no API key).
/// Degrades silently when offline — the dashboard just hides the weather chip.
@Observable
final class WeatherService {
    var temperatureF: Int?
    var windMph: Int?
    var conditionSymbol = "cloud.sun.fill"

    var summary: String? {
        guard let temperatureF, let windMph else { return nil }
        return "\(temperatureF)° · wind \(windMph) mph"
    }

    func refresh(coordinate: CLLocationCoordinate2D?) async {
        // Fall back to a Twin Cities default until GPS locks.
        let lat = coordinate?.latitude ?? 44.98
        let lon = coordinate?.longitude ?? -93.27
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,wind_speed_10m,weather_code"),
            .init(name: "temperature_unit", value: "fahrenheit"),
            .init(name: "wind_speed_unit", value: "mph"),
        ]
        guard let url = components.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            temperatureF = Int(response.current.temperature_2m.rounded())
            windMph = Int(response.current.wind_speed_10m.rounded())
            conditionSymbol = Self.symbol(for: response.current.weather_code)
        } catch {
            // Offline: keep whatever we last had.
        }
    }

    private static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let wind_speed_10m: Double
            let weather_code: Int
        }
        let current: Current
    }
}
