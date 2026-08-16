import MapKit
import SwiftUI

struct DestinationBar: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @Environment(\.appearance) private var appearance
    @AppStorage("speedUnit") private var storedUnit: String = SpeedUnit.kilometersPerHour.rawValue
    @AppStorage("travelMode") private var storedTravelMode: String = TravelMode.drive.rawValue
    let onSearchTap: () -> Void

    private var colors: Palette { Theme.palette(appearance) }
    private var unit: SpeedUnit { SpeedUnit(rawValue: storedUnit) ?? .kilometersPerHour }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onSearchTap) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: leadingSymbol)
                        .font(.system(size: navigationManager.hasRoute ? 22 : 17, weight: .semibold))
                        .foregroundStyle(Theme.accent(appearance))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(primaryText)
                            .font(.system(size: navigationManager.hasRoute ? 18 : 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(colors.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(secondaryText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(navigationManager.hasRoute ? Theme.accent(appearance) : colors.tertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(navigationManager.hasRoute ? "Change destination" : "Search destination")

            if navigationManager.hasDestination {
                Button {
                    navigationManager.clearDestination()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(colors.secondary)
                        .frame(width: 44, height: 44)
                        .background(colors.chipTrack, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear destination")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, navigationManager.hasRoute ? 14 : 12)
        .frame(minHeight: Theme.controlSize)
        .hudSurface(cornerRadius: Theme.pillRadius, stroke: colors.stroke)
    }

    private var leadingSymbol: String {
        if navigationManager.hasRoute {
            return "arrow.triangle.turn.up.right.diamond.fill"
        }
        let mode = TravelMode(rawValue: storedTravelMode) ?? .drive
        return navigationManager.hasDestination ? "flag.checkered" : mode.symbol
    }

    private var primaryText: String {
        if let instruction = navigationManager.nextInstruction, navigationManager.hasRoute {
            return instruction
        }
        if navigationManager.hasDestination {
            return destinationTitle
        }
        return "Where to?"
    }

    private var secondaryText: String {
        if navigationManager.hasRoute {
            let maneuver = Formatters.distance(navigationManager.distanceToManeuver, unit: unit)
            if let road = navigationManager.mainRoad {
                return "in \(maneuver)  ·  \(road)"
            }
            return "in \(maneuver)"
        }
        if navigationManager.isCalculating {
            return "Finding the fastest route"
        }
        if let street = locationManager.currentStreet {
            return street
        }
        return "Address, place, or road"
    }

    private var destinationTitle: String {
        navigationManager.destination?.name
            ?? navigationManager.destination?.placemark.title
            ?? "Destination"
    }
}
