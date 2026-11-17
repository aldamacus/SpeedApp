import CoreLocation
import MapKit
import SwiftUI
import UIKit

enum AppTab: Int {
    case map = 0
    case hud = 1
}

struct DrivingView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var cameraManager: CameraManager

    @AppStorage("speedUnit") private var storedUnit: String = SpeedUnit.kilometersPerHour.rawValue
    @AppStorage("appearanceMode") private var storedAppearance: String = AppearanceMode.night.rawValue
    @AppStorage("travelMode") private var storedTravelMode: String = TravelMode.drive.rawValue
    @AppStorage("driveCameraDistance") private var driveCameraDistance: Double = 850
    @AppStorage("rideCameraDistance") private var rideCameraDistance: Double = 460
    @State private var selectedTab: Int = AppTab.map.rawValue
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var followUser = true
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var dropTarget: MapDropTarget?
    @State private var dropPulse = 0

    private var unit: Binding<SpeedUnit> {
        Binding(
            get: { SpeedUnit(rawValue: storedUnit) ?? .kilometersPerHour },
            set: { storedUnit = $0.rawValue }
        )
    }

    private var appearance: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: storedAppearance) ?? .night },
            set: { storedAppearance = $0.rawValue }
        )
    }

    private var travelMode: Binding<TravelMode> {
        Binding(
            get: { TravelMode(rawValue: storedTravelMode) ?? .drive },
            set: { storedTravelMode = $0.rawValue }
        )
    }

    private var cameraDistance: Binding<CLLocationDistance> {
        Binding(
            get: {
                travelMode.wrappedValue == .drive ? driveCameraDistance : rideCameraDistance
            },
            set: { value in
                if travelMode.wrappedValue == .drive {
                    driveCameraDistance = value
                } else {
                    rideCameraDistance = value
                }
            }
        )
    }

    private var colors: Palette { Theme.palette(appearance.wrappedValue) }

    var body: some View {
        ZStack {
            mapTab
                .opacity(selectedTab == AppTab.map.rawValue ? 1 : 0)
                .allowsHitTesting(selectedTab == AppTab.map.rawValue)
                .accessibilityHidden(selectedTab != AppTab.map.rawValue)
            if selectedTab == AppTab.hud.rawValue {
                hudTab
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .overlay {
            if needsPermissionPrompt {
                permissionOverlay
            }
        }
        .onAppear {
            locationManager.requestAccessAndStart()
            locationManager.applyTravelMode(travelMode.wrappedValue)
            navigationManager.updateTravelMode(travelMode.wrappedValue, from: locationManager.location)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: locationManager.location?.timestamp) { _, _ in
            if let location = locationManager.location {
                navigationManager.updateProgress(from: location)
                cameraManager.update(location: location, heading: locationManager.heading)
            }
        }
        .sensoryFeedback(.warning, trigger: cameraManager.alert?.camera.id)
        .sensoryFeedback(.impact(weight: .medium), trigger: dropPulse)
        .onChange(of: followUser) { _, following in
            if following, !navigationManager.hasDestination {
                dropTarget = nil
            }
        }
        .sheet(isPresented: $showSearch) {
            PlaceSearchSheet(travelMode: travelMode)
                .environmentObject(locationManager)
                .environmentObject(navigationManager)
                .preferredColorScheme(appearance.wrappedValue.colorScheme)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(unit: unit, appearance: appearance, travelMode: travelMode)
        }
        .onChange(of: storedTravelMode) { _, _ in
            locationManager.applyTravelMode(travelMode.wrappedValue)
            navigationManager.updateTravelMode(travelMode.wrappedValue, from: locationManager.location)
        }
        .environment(\.appearance, appearance.wrappedValue)
        .preferredColorScheme(appearance.wrappedValue.colorScheme)
        .animation(.snappy(duration: 0.25), value: storedAppearance)
        .animation(.snappy(duration: 0.28), value: navigationManager.hasRoute)
        .animation(.snappy(duration: 0.22), value: followUser)
        .onChange(of: navigationManager.route?.polyline.pointCount) { _, _ in
            fitRouteIfNeeded()
        }
        .statusBarHidden(false)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            DestinationBar { showSearch = true }
            circleButton(systemName: "gearshape.fill", accessibility: "Settings") {
                showSettings = true
            }
        }
    }

    /// Tab 1: the full-screen map with search, settings and recenter.
    private var mapTab: some View {
        ZStack(alignment: .top) {
            RouteMapView(
                cameraPosition: $cameraPosition,
                followUser: $followUser,
                cameraDistance: cameraDistance,
                dropTarget: $dropTarget,
                travelMode: travelMode.wrappedValue,
                onDropPin: handleDroppedPin
            )
            .ignoresSafeArea(edges: .top)

            LinearGradient(
                colors: [colors.overlayTop, .clear, .clear, colors.overlayBottom.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                header
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                if let message = navigationManager.errorMessage, !navigationManager.hasRoute {
                    Text(message)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.red.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if !followUser {
                    HStack {
                        Spacer()
                        locationButton
                            .transition(.scale(scale: 0.86).combined(with: .opacity))
                    }
                }
                if let dropTarget, !navigationManager.hasDestination {
                    driveHereCard(dropTarget)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Map", systemName: "map.fill", tab: .map)
            tabButton(title: "HUD", systemName: "speedometer", tab: .hud)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(colors.stroke)
                .frame(height: 1)
        }
    }

    private func tabButton(title: String, systemName: String, tab: AppTab) -> some View {
        let selected = selectedTab == tab.rawValue
        return Button {
            selectedTab = tab.rawValue
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selected ? Theme.accent(appearance.wrappedValue) : colors.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Tab 2: the speedometer HUD on a plain themed background.
    private var hudTab: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            SpeedClusterView(unit: unit)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    private func handleDroppedPin(_ coordinate: CLLocationCoordinate2D) {
        dropTarget = MapDropTarget(coordinate: coordinate)
        dropPulse += 1
        reverseGeocode(coordinate)
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { places, _ in
            guard let place = places?.first else { return }
            let name = [place.name, place.thoroughfare]
                .compactMap { $0 }
                .first { !$0.isEmpty }
                ?? "Dropped pin"
            DispatchQueue.main.async {
                guard dropTarget?.coordinate.latitude == coordinate.latitude else { return }
                dropTarget?.name = name
            }
        }
    }

    private func confirmDriveHere(_ target: MapDropTarget) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: target.coordinate))
        item.name = target.name
        navigationManager.setDestination(item, from: locationManager.location)
        dropTarget = nil
    }

    private func driveHereCard(_ target: MapDropTarget) -> some View {
        let distanceText: String = {
            guard let here = locationManager.location else { return "Hold to set destination" }
            let there = CLLocation(latitude: target.latitude, longitude: target.longitude)
            return "\(Formatters.distance(here.distance(from: there), unit: unit.wrappedValue)) away"
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.accent(appearance.wrappedValue))
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(colors.primary)
                        .lineLimit(2)
                    Text(distanceText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(colors.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    dropTarget = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(colors.secondary)
                        .frame(width: 32, height: 32)
                        .background(colors.chipTrack, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")
            }

            Button {
                confirmDriveHere(target)
            } label: {
                Text(travelMode.wrappedValue.goHereTitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent(appearance.wrappedValue))
            .foregroundStyle(.white)
        }
        .padding(14)
        .hudSurface(cornerRadius: 22, stroke: colors.stroke)
        .accessibilityElement(children: .contain)
    }

    private var locationButton: some View {
        Button {
            followUser = true
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent(appearance.wrappedValue))
                .frame(width: Theme.locationButtonSize, height: Theme.locationButtonSize)
                .hudSurface(cornerRadius: Theme.locationButtonSize / 2, stroke: colors.stroke)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Current location")
        .accessibilityHint("Returns the map to where you are now.")
    }

    private func circleButton(systemName: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(colors.icon)
                .frame(width: Theme.controlSize, height: Theme.controlSize)
                .hudSurface(cornerRadius: Theme.controlSize / 2, stroke: colors.stroke)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    private var needsPermissionPrompt: Bool {
        if locationManager.locationServicesOff { return true }
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var permissionOverlay: some View {
        ZStack {
            colors.permissionScrim.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent(appearance.wrappedValue))
                Text(locationManager.locationServicesOff ? "Turn on Location Services" : "Location needed")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.primary)
                Text(
                    locationManager.locationServicesOff
                        ? "Location Services is off on this iPhone. Turn it on in Settings so Speed can show your speed and route."
                        : "Allow location access so Speed can show your speed, draw the driving route, and estimate arrival time."
                )
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(colors.permissionText)
                    .padding(.horizontal, 12)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(appearance.wrappedValue))
                .foregroundStyle(.white)
            }
            .padding(24)
            .hudSurface(cornerRadius: 28, stroke: colors.stroke)
            .padding(.horizontal, 20)
        }
    }

    private func fitRouteIfNeeded() {
        guard let route = navigationManager.route else { return }
        followUser = false
        let rect = route.polyline.boundingMapRect
        cameraPosition = .rect(rect.insetBy(dx: -rect.size.width * 0.18, dy: -rect.size.height * 0.22))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            followUser = true
        }
    }
}

#Preview {
    DrivingView()
        .environmentObject(LocationManager())
        .environmentObject(NavigationManager())
        .environmentObject(CameraManager())
}
