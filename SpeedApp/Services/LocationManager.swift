import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var heading: CLLocationDirection = 0
    @Published var speedMetersPerSecond: Double = 0
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentStreet: String?
    @Published var locationServicesOff = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodeLocation: CLLocation?
    private var smoothedSpeed: Double = 0

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 5
        manager.headingFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestAccessAndStart() {
        locationServicesOff = !CLLocationManager.locationServicesEnabled()
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdates()
        default:
            stopUpdates()
        }
    }

    func applyTravelMode(_ mode: TravelMode) {
        manager.activityType = mode.activityType
    }

    func startUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationServicesOff = true
            return
        }
        locationServicesOff = false
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    private func applySpeed(_ raw: Double) {
        guard raw >= 0 else { return }
        let clamped = raw < 0.4 ? 0 : raw
        smoothedSpeed = smoothedSpeed * 0.65 + clamped * 0.35
        speedMetersPerSecond = smoothedSpeed
    }

    private func refreshStreetName(for location: CLLocation) {
        if let last = lastGeocodeLocation, location.distance(from: last) < 400 {
            return
        }
        lastGeocodeLocation = location
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] places, _ in
            Task { @MainActor in
                self?.currentStreet = places?.first?.thoroughfare
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            locationServicesOff = !CLLocationManager.locationServicesEnabled()
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdates()
            default:
                stopUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            location = latest
            applySpeed(latest.speed)
            refreshStreetName(for: latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard value >= 0 else { return }
        Task { @MainActor in
            heading = value
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                Task { @MainActor in
                    authorizationStatus = manager.authorizationStatus
                    stopUpdates()
                }
                return
            case .locationUnknown, .headingFailure, .network:
                return
            default:
                break
            }
        }
        #if DEBUG
        print("Location error: \(error.localizedDescription)")
        #endif
    }
}
