import Foundation
import CoreLocation
import Observation

/// Thin wrapper around CoreLocation: permission, current fix, reverse geocode.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var lastCoordinate: CLLocationCoordinate2D?
    var lastAddress: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastCoordinate = location.coordinate
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Offline / denied: knocks still log, just without GPS.
    }

    private func reverseGeocode(_ location: CLLocation) {
        guard !geocoder.isGeocoding else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let number = placemark.subThoroughfare ?? ""
            let street = placemark.thoroughfare ?? ""
            let address = "\(number) \(street)".trimmingCharacters(in: .whitespaces)
            self?.lastAddress = address.isEmpty ? placemark.locality : address
        }
    }
}
