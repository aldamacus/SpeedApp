import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct DrivingView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var cameraManager: CameraManager

    @AppStorage("speedUnit") private var storedUnit: String = SpeedUnit.kilometersPerHour.rawValue
    @AppStorage("appearanceMode") private var storedAppearance: String = AppearanceMode.night.rawValue
    @AppStorage("travelMode") private var storedTravelMode: String = TravelMode.drive.rawValue
    @AppStorage("mapHeadingMode") private var storedHeadingMode: String = MapHeadingMode.driver.rawValue
    @AppStorage("driveCameraDistance") private var driveCameraDistance: Double = 850
    @AppStorage("rideCameraDistance") private var rideCameraDistance: Double = 460
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var followUser = true
    @State private var showSearch = false
    @State private var showSettings = false
    @State private var hudDragOrigin: Double?
    @State private var dropTarget: MapDropTarget?
    @State private var dropPulse = 0

    @AppStorage("hudFraction") private var hudFraction: Double = 0.36

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

    private var headingMode: Binding<MapHeadingMode> {
        Binding(
            get: { MapHeadingMode(rawValue: storedHeadingMode) ?? .driver },
            set: { storedHeadingMode = $0.rawValue }
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
        GeometryReader { geo in
            let handle = Theme.splitHandleHeight
            let hudBody = max(120, geo.size.height * CGFloat(hudFraction) - handle)
            let mapHeight = geo.size.height - hudBody - handle

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    RouteMapView(
                        cameraPosition: $cameraPosition,
                        followUser: $followUser,
                        cameraDistance: cameraDistance,
                        dropTarget: $dropTarget,
                        travelMode: travelMode.wrappedValue,
                        headingMode: headingMode.wrappedValue,
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
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                headingModeButton
                                if !followUser {
                                    locationButton
                                        .transition(.scale(scale: 0.86).combined(with: .opacity))
                                }
                            }
                        }
                        if let dropTarget, !navigationManager.hasDestination {
                            driveHereCard(dropTarget)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
                .frame(height: mapHeight)
                .clipped()

                VStack(spacing: 0) {
                    splitHandle(totalHeight: geo.size.height)
                    SpeedClusterView(unit: unit)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                }
                .frame(height: hudBody + handle)
                .hudSheetSurface(stroke: colors.stroke)
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
            SettingsView(unit: unit, appearance: appearance, travelMode: travelMode, headingMode: headingMode)
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
        .animation(.snappy(duration: 0.22), value: storedHeadingMode)
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

    private func splitHandle(totalHeight: CGFloat) -> some View {
        Capsule()
            .fill(colors.tertiary)
            .frame(width: 42, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.splitHandleHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if hudDragOrigin == nil {
                            hudDragOrigin = hudFraction
                        }
                        let next = (hudDragOrigin ?? hudFraction) - Double(value.translation.height) / max(Double(totalHeight), 1)
                        hudFraction = min(Theme.maxHudFraction, max(Theme.minHudFraction, next))
                    }
                    .onEnded { _ in
                        withAnimation(.snappy(duration: 0.22)) {
                            hudFraction = snappedHudFraction(hudFraction)
                        }
                        hudDragOrigin = nil
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy(duration: 0.28)) {
                    hudFraction = hudFraction < 0.5 ? Theme.maxHudFraction : Theme.minHudFraction
                }
            }
            .accessibilityLabel("Map and HUD split")
            .accessibilityHint("Drag to resize. Double tap to switch between a large map and a large HUD.")
            .accessibilityValue("HUD \(Int((hudFraction * 100).rounded())) percent")
            .accessibilityAdjustableAction { direction in
                withAnimation(.snappy(duration: 0.2)) {
                    switch direction {
                    case .increment:
                        hudFraction = min(Theme.maxHudFraction, hudFraction + 0.25)
                    case .decrement:
                        hudFraction = max(Theme.minHudFraction, hudFraction - 0.25)
                    default:
                        break
                    }
                    hudFraction = snappedHudFraction(hudFraction)
                }
            }
    }

    private func snappedHudFraction(_ value: Double) -> Double {
        let stops: [Double] = [Theme.minHudFraction, 0.5, Theme.maxHudFraction]
        guard let nearest = stops.min(by: { abs($0 - value) < abs($1 - value) }) else { return value }
        return abs(nearest - value) < 0.07 ? nearest : min(Theme.maxHudFraction, max(Theme.minHudFraction, value))
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

    private var headingModeButton: some View {
        Button {
            headingMode.wrappedValue = headingMode.wrappedValue == .driver ? .north : .driver
            followUser = true
        } label: {
            Image(systemName: headingMode.wrappedValue.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent(appearance.wrappedValue))
                .frame(width: Theme.locationButtonSize, height: Theme.locationButtonSize)
                .hudSurface(cornerRadius: Theme.locationButtonSize / 2, stroke: colors.stroke)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(headingMode.wrappedValue.accessibilityLabel)
        .accessibilityHint("Switches between driver view and north up.")
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
