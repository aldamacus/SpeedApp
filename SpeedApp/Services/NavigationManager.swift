import Combine
import CoreLocation
import Foundation
import MapKit

@MainActor
final class NavigationManager: ObservableObject {
    @Published var destination: MKMapItem?
    @Published var route: MKRoute?
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var distanceToManeuver: CLLocationDistance = 0
    @Published var mainRoad: String?
    @Published var nextInstruction: String?
    @Published var isCalculating = false
    @Published var errorMessage: String?
    @Published var travelMode: TravelMode = .drive

    private var lastRouteLocation: CLLocation?
    private var lastRouteDate: Date = .distantPast
    private var routeTask: Task<Void, Never>?
    private var directions: MKDirections?
    private var calculationID = UUID()

    var hasDestination: Bool { destination != nil }
    var hasRoute: Bool { route != nil }

    func setDestination(_ item: MKMapItem, from location: CLLocation?) {
        destination = item
        errorMessage = nil
        lastRouteLocation = nil
        lastRouteDate = .distantPast
        if let location {
            recalculate(from: location, force: true)
        }
    }

    func updateTravelMode(_ mode: TravelMode, from location: CLLocation?) {
        let changed = travelMode != mode
        travelMode = mode
        guard changed, destination != nil, let location else { return }
        recalculate(from: location, force: true)
    }

    func clearDestination() {
        routeTask?.cancel()
        directions?.cancel()
        destination = nil
        route = nil
        remainingDistance = 0
        remainingTime = 0
        distanceToManeuver = 0
        mainRoad = nil
        nextInstruction = nil
        errorMessage = nil
    }

    func updateProgress(from location: CLLocation) {
        guard destination != nil else { return }

        if let route {
            let progress = RouteMath.progress(along: route, from: location)
            remainingDistance = max(progress.remainingDistance, 0)
            remainingTime = estimatedTime(remaining: remainingDistance, fallback: route.expectedTravelTime)
            nextInstruction = progress.nextInstruction
            distanceToManeuver = progress.distanceToManeuver
        }

        let movedFar = lastRouteLocation.map { location.distance(from: $0) > 150 } ?? true
        let stale = Date().timeIntervalSince(lastRouteDate) > 30
        if movedFar || stale {
            recalculate(from: location, force: false)
        }
    }

    private func estimatedTime(remaining: CLLocationDistance, fallback: TimeInterval) -> TimeInterval {
        if remaining <= 15 { return 0 }
        if let full = route?.distance, full > 0 {
            return fallback * (remaining / full)
        }
        return fallback
    }

    private func recalculate(from location: CLLocation, force: Bool) {
        guard let destination else { return }
        if isCalculating && !force { return }

        routeTask?.cancel()
        directions?.cancel()

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = destination
        request.transportType = .automobile
        request.departureDate = Date()
        request.requestsAlternateRoutes = true

        let job = MKDirections(request: request)
        let id = UUID()
        directions = job
        calculationID = id
        isCalculating = true
        lastRouteLocation = location
        lastRouteDate = Date()

        routeTask = Task {
            defer {
                if calculationID == id {
                    isCalculating = false
                }
            }
            do {
                let response = try await calculate(job)
                guard !Task.isCancelled, calculationID == id else { return }
                let best = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime })
                route = best
                if let best {
                    remainingDistance = best.distance
                    remainingTime = best.expectedTravelTime
                    distanceToManeuver = RouteMath.firstManeuverDistance(from: best)
                    mainRoad = RouteMath.mainRoad(from: best)
                    nextInstruction = RouteMath.firstInstruction(from: best)
                    errorMessage = nil
                }
            } catch {
                if !Task.isCancelled, calculationID == id {
                    errorMessage = travelMode.routeError
                }
            }
        }
    }

    private func calculate(_ directions: MKDirections) async throws -> MKDirections.Response {
        try await withCheckedThrowingContinuation { continuation in
            directions.calculate { response, error in
                if let response {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: error ?? URLError(.cannotFindHost))
                }
            }
        }
    }
}

enum RouteMath {
    static func mainRoad(from route: MKRoute) -> String {
        if !route.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return route.name
        }
        let longest = route.steps.max(by: { $0.distance < $1.distance })
        if let text = longest?.instructions, let road = roadName(from: text) {
            return road
        }
        return "Fastest route"
    }

    static func firstInstruction(from route: MKRoute) -> String? {
        route.steps.first(where: { $0.distance > 20 && !$0.instructions.isEmpty })?.instructions
    }

    static func firstManeuverDistance(from route: MKRoute) -> CLLocationDistance {
        route.steps.first(where: { $0.distance > 20 })?.distance ?? route.distance
    }

    static func progress(along route: MKRoute, from location: CLLocation) -> (remainingDistance: CLLocationDistance, nextInstruction: String?, distanceToManeuver: CLLocationDistance) {
        let closest = closestPoint(on: route.polyline, to: location)
        let remaining = remainingDistance(on: route.polyline, fromVertex: closest.vertexIndex, closest: closest.point)
        let upcoming = upcomingManeuver(in: route, remainingDistance: remaining)
        return (remaining, upcoming.instruction, upcoming.distance)
    }

    private static func upcomingManeuver(in route: MKRoute, remainingDistance: CLLocationDistance) -> (instruction: String?, distance: CLLocationDistance) {
        var distanceFromEnd = remainingDistance
        for step in route.steps.reversed() {
            if distanceFromEnd <= step.distance + 40 {
                let instruction = step.instructions.isEmpty ? nil : step.instructions
                return (instruction, max(0, distanceFromEnd))
            }
            distanceFromEnd -= step.distance
        }
        return (firstInstruction(from: route), remainingDistance)
    }

    private static func closestPoint(on polyline: MKPolyline, to location: CLLocation) -> (point: MKMapPoint, vertexIndex: Int) {
        let mapPoint = MKMapPoint(location.coordinate)
        let points = polyline.points()
        var bestDistance = Double.greatestFiniteMagnitude
        var bestPoint = mapPoint
        var bestIndex = 0

        guard polyline.pointCount > 1 else {
            return (MKMapPoint(polyline.coordinate), 0)
        }

        for index in 0 ..< (polyline.pointCount - 1) {
            let start = points[index]
            let end = points[index + 1]
            let candidate = project(mapPoint, onto: start, end)
            let distance = hypot(mapPoint.x - candidate.x, mapPoint.y - candidate.y)
            if distance < bestDistance {
                bestDistance = distance
                bestPoint = candidate
                bestIndex = index
            }
        }
        return (bestPoint, bestIndex)
    }

    private static func remainingDistance(on polyline: MKPolyline, fromVertex index: Int, closest: MKMapPoint) -> CLLocationDistance {
        let points = polyline.points()
        guard polyline.pointCount > 1 else { return 0 }

        var total = closest.distance(to: points[min(index + 1, polyline.pointCount - 1)])
        if index + 1 < polyline.pointCount - 1 {
            for vertex in (index + 1) ..< (polyline.pointCount - 1) {
                total += points[vertex].distance(to: points[vertex + 1])
            }
        }
        return total
    }

    private static func project(_ point: MKMapPoint, onto start: MKMapPoint, _ end: MKMapPoint) -> MKMapPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return start }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return MKMapPoint(x: start.x + t * dx, y: start.y + t * dy)
    }

    private static func roadName(from instruction: String) -> String? {
        let markers = [" onto ", " on ", " toward "]
        for marker in markers {
            if let range = instruction.range(of: marker, options: .caseInsensitive) {
                let name = instruction[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }
        return instruction.isEmpty ? nil : instruction
    }
}
