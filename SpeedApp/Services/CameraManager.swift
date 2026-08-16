import Combine
import CoreLocation
import Foundation

struct RoadCamera: Identifiable, Equatable {
    let id: Int64
    let coordinate: CLLocationCoordinate2D
    let speedLimitKmh: Int?

    static func == (lhs: RoadCamera, rhs: RoadCamera) -> Bool {
        lhs.id == rhs.id
    }
}

struct CameraAlert: Equatable {
    let camera: RoadCamera
    let distance: CLLocationDistance
}

@MainActor
final class CameraManager: ObservableObject {
    @Published private(set) var cameras: [RoadCamera] = []
    @Published private(set) var alert: CameraAlert?

    private var lastFetchLocation: CLLocation?
    private var lastFetchDate = Date.distantPast
    private var fetchTask: Task<Void, Never>?

    func update(location: CLLocation, heading: CLLocationDirection) {
        refreshIfNeeded(around: location)
        alert = nearestAhead(from: location, heading: heading)
    }

    private func refreshIfNeeded(around location: CLLocation) {
        let moved = lastFetchLocation.map { location.distance(from: $0) > 2_400 } ?? true
        let stale = Date().timeIntervalSince(lastFetchDate) > 40
        guard moved || stale else { return }
        lastFetchLocation = location
        lastFetchDate = Date()
        fetchTask?.cancel()
        fetchTask = Task {
            let found = await Self.loadCameras(near: location.coordinate)
            guard !Task.isCancelled else { return }
            cameras = found
        }
    }

    private func nearestAhead(from location: CLLocation, heading: CLLocationDirection) -> CameraAlert? {
        let candidates = cameras.compactMap { camera -> CameraAlert? in
            let here = CLLocation(latitude: camera.coordinate.latitude, longitude: camera.coordinate.longitude)
            let distance = location.distance(from: here)
            guard distance < 1_000 else { return nil }
            let bearing = location.coordinate.bearing(to: camera.coordinate)
            var delta = abs(bearing - heading)
            if delta > 180 { delta = 360 - delta }
            guard delta < 75 || distance < 70 else { return nil }
            return CameraAlert(camera: camera, distance: distance)
        }
        return candidates.min(by: { $0.distance < $1.distance })
    }

    private static func loadCameras(near coordinate: CLLocationCoordinate2D) async -> [RoadCamera] {
        let query = """
        [out:json][timeout:12];
        (
          node["highway"="speed_camera"](around:8000,\(coordinate.latitude),\(coordinate.longitude));
          node["enforcement"="maxspeed"](around:8000,\(coordinate.latitude),\(coordinate.longitude));
        );
        out body;
        """
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("SpeedApp/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)".data(using: .utf8)
        request.timeoutInterval = 14

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
            return decoded.elements.compactMap { element in
                guard let lat = element.lat, let lon = element.lon else { return nil }
                return RoadCamera(
                    id: element.id,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    speedLimitKmh: Self.parseSpeed(element.tags?["maxspeed"])
                )
            }
        } catch {
            return []
        }
    }

    private static func parseSpeed(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        let digits = raw.split(whereSeparator: { !$0.isNumber }).first
        guard let digits, let value = Int(digits) else { return nil }
        if raw.lowercased().contains("mph") {
            return Int((Double(value) * 1.60934).rounded())
        }
        return value
    }
}

private struct OverpassResponse: Decodable {
    let elements: [Element]

    struct Element: Decodable {
        let id: Int64
        let lat: Double?
        let lon: Double?
        let tags: [String: String]?
    }
}

private extension CLLocationCoordinate2D {
    func bearing(to other: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return fmod(bearing + 360, 360)
    }
}
