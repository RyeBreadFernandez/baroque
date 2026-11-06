import Foundation
import CoreLocation

@MainActor
final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: String = ""
    @Published var isWorking = false

    private let manager = CLLocationManager()
    private var completion: ((Double, Double, String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestOnce(_ done: @escaping (Double, Double, String) -> Void) {
        completion = done
        isWorking = true
        status = "Locating..."
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isWorking = false
            status = "Location permission denied. Enter coordinates manually or enable it in Settings."
        default:
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            guard self.completion != nil else { return }
            if s == .authorizedWhenInUse || s == .authorizedAlways {
                manager.requestLocation()
            } else if s == .denied || s == .restricted {
                self.isWorking = false
                self.status = "Location permission denied."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        Task { @MainActor in
            var city = "Current location"
            if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(loc), let p = placemarks.first {
                city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? city
            }
            self.isWorking = false
            self.status = "Set to \(city)"
            self.completion?(lat, lon, city)
            self.completion = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isWorking = false
            self.status = "Location failed: \(error.localizedDescription)"
            self.completion = nil
        }
    }
}
