import CoreLocation
import Foundation

enum SpeedUnit: String, CaseIterable, Identifiable {
    case kilometersPerHour
    case milesPerHour

    var id: String { rawValue }

    static var fromLocale: SpeedUnit { .kilometersPerHour }

    var label: String {
        switch self {
        case .kilometersPerHour: return "km/h"
        case .milesPerHour: return "mph"
        }
    }

    var settingsTitle: String {
        switch self {
        case .kilometersPerHour: return "Kilometers"
        case .milesPerHour: return "Miles"
        }
    }

    var settingsDetail: String {
        switch self {
        case .kilometersPerHour: return "km/h and km"
        case .milesPerHour: return "mph and miles"
        }
    }

    func value(fromMetersPerSecond speed: Double) -> Double {
        switch self {
        case .kilometersPerHour: return speed * 3.6
        case .milesPerHour: return speed * 2.236936
        }
    }

    var distanceUnit: UnitLength {
        switch self {
        case .kilometersPerHour: return .kilometers
        case .milesPerHour: return .miles
        }
    }
}

enum TravelMode: String, CaseIterable, Identifiable {
    case drive
    case ride

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .drive: return "Drive"
        case .ride: return "Ride"
        }
    }

    var settingsDetail: String {
        switch self {
        case .drive: return "Car view. Hold the map to look and zoom."
        case .ride: return "Motorcycle view. Hold the map to look and zoom."
        }
    }

    var symbol: String {
        switch self {
        case .drive: return "car.fill"
        case .ride: return "motorcycle.fill"
        }
    }

    var activityType: CLActivityType {
        switch self {
        case .drive: return .automotiveNavigation
        case .ride: return .otherNavigation
        }
    }

    var routeError: String {
        switch self {
        case .drive: return "Could not find a driving route."
        case .ride: return "Could not find a riding route."
        }
    }

    var goHereTitle: String {
        switch self {
        case .drive: return "Drive here"
        case .ride: return "Ride here"
        }
    }

    func defaultCameraDistance(hasRoute: Bool) -> CLLocationDistance {
        switch self {
        case .drive: return hasRoute ? 850 : 1300
        case .ride: return hasRoute ? 460 : 880
        }
    }

    func cameraPitch(hasRoute: Bool) -> Double {
        switch self {
        case .drive: return hasRoute ? 52 : 36
        case .ride: return hasRoute ? 64 : 46
        }
    }

    func lookAhead(hasRoute: Bool) -> CLLocationDistance {
        switch self {
        case .drive: return hasRoute ? 120 : 70
        case .ride: return hasRoute ? 70 : 45
        }
    }

    static let minCameraDistance: CLLocationDistance = 220
    static let maxCameraDistance: CLLocationDistance = 16000
}

enum MapHeadingMode: String, CaseIterable, Identifiable {
    case driver
    case north

    var id: String { rawValue }

    var settingsTitle: String {
        switch self {
        case .driver: return "Driver"
        case .north: return "North"
        }
    }

    var settingsDetail: String {
        switch self {
        case .driver: return "Map turns with the car"
        case .north: return "North stays at the top"
        }
    }

    var symbol: String {
        switch self {
        case .driver: return "location.north.line.fill"
        case .north: return "location.north.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .driver: return "Driver view"
        case .north: return "North up"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .driver: return "Map follows the direction you are driving."
        case .north: return "North stays at the top of the map."
        }
    }

    mutating func toggle() {
        self = self == .driver ? .north : .driver
    }
}

struct TravelTime: Equatable {
    let hours: Int
    let minutes: Int

    static func remaining(from seconds: TimeInterval) -> TravelTime {
        let total = max(0, Int(seconds.rounded()))
        let roundedMinutes = Int((Double(total) / 60.0).rounded())
        return TravelTime(hours: roundedMinutes / 60, minutes: roundedMinutes % 60)
    }

    var hoursText: String { "\(hours)" }
    var minutesText: String { String(format: "%02d", minutes) }
    var phrase: String { "\(hours) hr \(minutesText) min" }
    var accessibility: String {
        hours == 1
            ? "1 hour \(minutes) minutes"
            : "\(hours) hours \(minutes) minutes"
    }
}

enum Formatters {
    static func speed(_ metersPerSecond: Double, unit: SpeedUnit) -> String {
        String(Int(unit.value(fromMetersPerSecond: metersPerSecond).rounded()))
    }

    static func eta(_ seconds: TimeInterval) -> TravelTime {
        TravelTime.remaining(from: seconds)
    }

    static func compactETA(_ seconds: TimeInterval) -> String {
        let time = TravelTime.remaining(from: seconds)
        if time.hours > 0 {
            return "\(time.hours)h \(time.minutesText)m"
        }
        return "\(time.minutes)m"
    }

    static func timeIfTraveling(kilometersPerHour: Double, remainingMeters: CLLocationDistance) -> TimeInterval {
        let metersPerSecond = kilometersPerHour / 3.6
        guard metersPerSecond > 0, remainingMeters > 0 else { return 0 }
        return remainingMeters / metersPerSecond
    }

    static func signedMinutes(from delta: TimeInterval) -> String {
        let minutes = Int((delta / 60.0).rounded())
        if minutes == 0 { return "same" }
        return minutes > 0 ? "+\(minutes)m" : "\(minutes)m"
    }

    static func arrivalClock(_ seconds: TimeInterval) -> String {
        let date = Date().addingTimeInterval(max(0, seconds))
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func distance(_ meters: CLLocationDistance, unit: SpeedUnit) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let converted = measurement.converted(to: unit.distanceUnit)
        let value = converted.value
        if unit == .kilometersPerHour {
            if value < 1 {
                return "\(Int((meters).rounded())) m"
            }
            return String(format: value >= 10 ? "%.0f km" : "%.1f km", value)
        } else {
            if value < 0.1 {
                let feet = measurement.converted(to: .feet).value
                return "\(Int(feet.rounded())) ft"
            }
            return String(format: value >= 10 ? "%.0f mi" : "%.1f mi", value)
        }
    }
}
