import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case day
    case night

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .day: return .light
        case .night: return .dark
        }
    }

    var settingsTitle: String {
        switch self {
        case .day: return "Day"
        case .night: return "Night"
        }
    }

    var settingsDetail: String {
        switch self {
        case .day: return "Light map and screen"
        case .night: return "Dark map and screen"
        }
    }

    var symbol: String {
        switch self {
        case .day: return "sun.max.fill"
        case .night: return "moon.fill"
        }
    }
}

struct Palette {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let overlayTop: Color
    let overlayBottom: Color
    let stroke: Color
    let chipTrack: Color
    let icon: Color
    let permissionScrim: Color
    let permissionText: Color

    static let night = Palette(
        primary: .white,
        secondary: .white.opacity(0.72),
        tertiary: .white.opacity(0.48),
        overlayTop: .black.opacity(0.22),
        overlayBottom: .black.opacity(0.58),
        stroke: .white.opacity(0.1),
        chipTrack: .black.opacity(0.28),
        icon: .white,
        permissionScrim: .black.opacity(0.82),
        permissionText: .white.opacity(0.7)
    )

    static let day = Palette(
        primary: Color(red: 0.07, green: 0.09, blue: 0.12),
        secondary: Color.black.opacity(0.58),
        tertiary: Color.black.opacity(0.4),
        overlayTop: .white.opacity(0.18),
        overlayBottom: .white.opacity(0.5),
        stroke: .black.opacity(0.08),
        chipTrack: Color.black.opacity(0.08),
        icon: Color(red: 0.07, green: 0.09, blue: 0.12),
        permissionScrim: .white.opacity(0.9),
        permissionText: Color.black.opacity(0.55)
    )
}

enum Theme {
    static let controlSize: CGFloat = 52
    static let locationButtonSize: CGFloat = 40
    static let pillRadius: CGFloat = 18
    static let hudRadius: CGFloat = 28
    static let splitHandleHeight: CGFloat = 28
    static let minHudFraction: Double = 0.25
    static let maxHudFraction: Double = 0.75
    static let defaultHudFraction: Double = 0.36

    static let dayAccent = Color(red: 0.1, green: 0.48, blue: 0.96)
    static let nightAccent = Color(red: 0.42, green: 0.78, blue: 1.0)
    static let dayTime = Color(red: 0.86, green: 0.16, blue: 0.16)
    static let nightTime = Color(red: 1.0, green: 0.34, blue: 0.32)
    static let dayCamera = Color(red: 0.95, green: 0.62, blue: 0.12)
    static let nightCamera = Color(red: 1.0, green: 0.78, blue: 0.28)
    static let dayRoute = Color(red: 0.12, green: 0.46, blue: 0.96)
    static let nightRoute = Color(red: 0.32, green: 0.7, blue: 1.0)

    static func palette(_ appearance: AppearanceMode) -> Palette {
        appearance == .day ? .day : .night
    }

    static func accent(_ appearance: AppearanceMode) -> Color {
        appearance == .day ? dayAccent : nightAccent
    }

    static func time(_ appearance: AppearanceMode) -> Color {
        appearance == .day ? dayTime : nightTime
    }

    static func camera(_ appearance: AppearanceMode) -> Color {
        appearance == .day ? dayCamera : nightCamera
    }

    static func route(_ appearance: AppearanceMode) -> Color {
        appearance == .day ? dayRoute : nightRoute
    }
}

extension View {
    func hudSurface(cornerRadius: CGFloat, stroke: Color) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
    }

    func hudSheetSurface(stroke: Color) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 20,
            style: .continuous
        )
        return background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(stroke, lineWidth: 1)
            }
    }
}

private struct AppearanceModeKey: EnvironmentKey {
    static let defaultValue = AppearanceMode.night
}

extension EnvironmentValues {
    var appearance: AppearanceMode {
        get { self[AppearanceModeKey.self] }
        set { self[AppearanceModeKey.self] = newValue }
    }
}
