import CoreLocation
import MapKit
import SwiftUI

struct RouteMapView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var cameraManager: CameraManager
    @Environment(\.appearance) private var appearance

    @Binding var cameraPosition: MapCameraPosition
    @Binding var followUser: Bool
    @Binding var cameraDistance: CLLocationDistance
    @Binding var dropTarget: MapDropTarget?
    let travelMode: TravelMode
    let onDropPin: (CLLocationCoordinate2D) -> Void

    /// Heading the map is currently rotated to. Smoothed so the map does not shake.
    @State private var displayHeading: CLLocationDirection = 0
    @State private var hasInitialHeading = false
    @State private var lateralOffset: CLLocationDistance = 0
    @State private var isLookingAround = false
    @State private var liveDistance: CLLocationDistance?
    @State private var dragStartDistance: CLLocationDistance?
    @State private var pinchStartDistance: CLLocationDistance?
    @State private var lookPulse = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if size.width > 8, size.height > 8 {
                mapContent
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        if followUser {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(lookGesture)
                                .simultaneousGesture(pinchGesture)
                                .onTapGesture(count: 2) {
                                    followUser = false
                                }
                        }
                    }
            } else {
                Color.black
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lookPulse)
    }

    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: followUser ? [] : .all) {
                if let location = locationManager.location {
                    Annotation("You", coordinate: location.coordinate, anchor: .center) {
                        // The map turns with the car, so the arrow always points up.
                        NavigationArrow()
                    }
                }

                if let destination = navigationManager.destination {
                    Marker(
                        destination.name ?? "Destination",
                        coordinate: destination.placemark.coordinate
                    )
                    .tint(Theme.accent(appearance))
                } else if let dropTarget {
                    Marker(dropTarget.name, coordinate: dropTarget.coordinate)
                        .tint(Theme.accent(appearance))
                }

                if let route = navigationManager.route {
                    MapPolyline(route.polyline)
                        .stroke(
                            Theme.route(appearance),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                        )
                }

                ForEach(cameraManager.cameras) { camera in
                    Annotation(
                        camera.speedLimitKmh.map { "\($0)" } ?? "Camera",
                        coordinate: camera.coordinate,
                        anchor: .center
                    ) {
                        SpeedCameraPin(limit: camera.speedLimitKmh, active: cameraManager.alert?.camera.id == camera.id)
                    }
                }
            }
            .mapStyle(simpleMapStyle)
            .mapControlVisibility(.hidden)
            .simultaneousGesture(dropPinGesture(proxy: proxy))
            .onChange(of: locationManager.location?.timestamp) { _, _ in
                updateFollowCamera()
            }
            .onChange(of: locationManager.heading) { _, _ in
                updateFollowCamera()
            }
            .onChange(of: navigationManager.hasRoute) { _, _ in
                updateFollowCamera()
            }
            .onChange(of: cameraDistance) { _, _ in
                updateFollowCamera()
            }
            .onChange(of: liveDistance) { _, _ in
                updateFollowCamera()
            }
            .onChange(of: lateralOffset) { _, _ in
                updateFollowCamera()
            }
            .onChange(of: travelMode) { _, _ in
                updateFollowCamera()
            }
            .onChange(of: followUser) { _, following in
                if following {
                    lateralOffset = 0
                    isLookingAround = false
                    updateFollowCamera()
                }
            }
        }
    }

    private func dropPinGesture(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 1.0)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                guard !followUser else { return }
                guard case .second(true, let drag) = value, let point = drag?.location else { return }
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                onDropPin(coordinate)
            }
    }

    private var lookGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragStartDistance == nil {
                    dragStartDistance = displayedDistance
                    isLookingAround = true
                    lookPulse += 1
                }
                let metersPerPoint = max(1.6, displayedDistance / 480)
                let maxLateral = displayedDistance * 0.55
                lateralOffset = min(max(-Double(value.translation.width) * metersPerPoint, -maxLateral), maxLateral)
                if abs(value.translation.height) > 12 {
                    let start = dragStartDistance ?? displayedDistance
                    liveDistance = clampedDistance(start * exp(Double(value.translation.height) / 260))
                }
            }
            .onEnded { value in
                if let liveDistance {
                    cameraDistance = liveDistance
                }
                dragStartDistance = nil
                liveDistance = nil
                isLookingAround = false
                if abs(value.translation.width) >= 18 {
                    followUser = false
                } else {
                    withAnimation(.easeOut(duration: 0.28)) {
                        lateralOffset = 0
                    }
                }
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchStartDistance == nil {
                    pinchStartDistance = displayedDistance
                }
                let start = pinchStartDistance ?? displayedDistance
                let factor = value.magnification < 1
                    ? pow(value.magnification, 1.18)
                    : value.magnification
                liveDistance = clampedDistance(start / factor)
            }
            .onEnded { _ in
                if let liveDistance {
                    cameraDistance = liveDistance
                }
                pinchStartDistance = nil
                liveDistance = nil
            }
    }

    private func updateFollowCamera() {
        guard followUser, let location = locationManager.location else { return }
        let hasRoute = navigationManager.hasRoute
        let travelHeading = smoothedHeading()
        let distance = displayedDistance
        let defaultDistance = travelMode.defaultCameraDistance(hasRoute: hasRoute)
        let lookAhead = travelMode.lookAhead(hasRoute: hasRoute) * max(1, distance / defaultDistance)
        var center = location.coordinate
        if lookAhead > 0 {
            center = center.shifting(meters: lookAhead, bearing: travelHeading)
        }
        if lateralOffset != 0 {
            center = center.shifting(meters: lateralOffset, bearing: travelHeading + 90)
        }
        let camera = MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: travelHeading,
            pitch: pitch(for: distance, hasRoute: hasRoute)
        )
        withAnimation(.linear(duration: 0.35)) {
            cameraPosition = .camera(camera)
        }
    }

    /// Low-pass filtered heading. Ignores small jitter and holds the last heading
    /// while standing still, so the rotating map stays calm like Waze.
    private func smoothedHeading() -> CLLocationDirection {
        let target = normalizedHeading(locationManager.heading)
        var delta = target - displayHeading
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let moving = locationManager.speedMetersPerSecond > 1
        // First fix: jump straight to the real heading.
        if !hasInitialHeading {
            displayHeading = target
            hasInitialHeading = true
        } else if moving, abs(delta) > 2 {
            displayHeading = normalizedHeading(displayHeading + delta * 0.4)
        }
        return displayHeading
    }

    private func pitch(for distance: CLLocationDistance, hasRoute: Bool) -> Double {
        let close = travelMode.cameraPitch(hasRoute: hasRoute)
        let far = 12.0
        let start = travelMode.defaultCameraDistance(hasRoute: hasRoute)
        let span = max(TravelMode.maxCameraDistance - start, 1)
        let t = min(1, max(0, (distance - start) / span))
        return close + (far - close) * (t * t)
    }

    private var displayedDistance: CLLocationDistance {
        liveDistance ?? cameraDistance
    }

    private func clampedDistance(_ value: CLLocationDistance) -> CLLocationDistance {
        min(max(value, TravelMode.minCameraDistance), TravelMode.maxCameraDistance)
    }

    private func normalizedHeading(_ value: CLLocationDirection) -> CLLocationDirection {
        var heading = value.truncatingRemainder(dividingBy: 360)
        if heading < 0 { heading += 360 }
        return heading
    }

    private var simpleMapStyle: MapStyle {
        if #available(iOS 18.0, *) {
            return .standard(
                elevation: .realistic,
                emphasis: .muted,
                pointsOfInterest: .excludingAll,
                showsTraffic: true
            )
        }
        return .standard(
            elevation: .realistic,
            pointsOfInterest: .excludingAll,
            showsTraffic: true
        )
    }
}

private struct SpeedCameraPin: View {
    @Environment(\.appearance) private var appearance
    let limit: Int?
    let active: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: active ? 30 : 24, height: active ? 30 : 24)
                .background(Theme.camera(appearance), in: Circle())
                .overlay {
                    Circle().stroke(.white, lineWidth: 2)
                }
            if let limit {
                Text("\(limit)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.palette(appearance).primary)
                    .padding(.horizontal, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

/// Waze-style navigation arrow: a fat arrowhead with a notched back, a thick white
/// outline and a soft shadow. It always points up because the map rotates instead.
private struct NavigationArrow: View {
    @Environment(\.appearance) private var appearance
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent(appearance).opacity(pulse ? 0.0 : 0.22))
                .frame(width: 64, height: 64)
                .scaleEffect(pulse ? 1.25 : 0.8)

            ArrowheadShape()
                .fill(Theme.accent(appearance))
                .overlay {
                    ArrowheadShape()
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                }
                .frame(width: 34, height: 40)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ArrowheadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY + h))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.74))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h))
        path.closeSubpath()
        return path
    }
}

private extension CLLocationCoordinate2D {
    func shifting(meters: CLLocationDistance, bearing: CLLocationDirection) -> CLLocationCoordinate2D {
        let radius = 6_378_137.0
        let bearingRadians = bearing * .pi / 180
        let latitudeRadians = latitude * .pi / 180
        let longitudeRadians = longitude * .pi / 180
        let angularDistance = meters / radius

        let newLatitude = asin(
            sin(latitudeRadians) * cos(angularDistance)
                + cos(latitudeRadians) * sin(angularDistance) * cos(bearingRadians)
        )
        let newLongitude = longitudeRadians + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(latitudeRadians),
            cos(angularDistance) - sin(latitudeRadians) * sin(newLatitude)
        )

        return CLLocationCoordinate2D(
            latitude: newLatitude * 180 / .pi,
            longitude: newLongitude * 180 / .pi
        )
    }
}

struct MapDropTarget: Equatable {
    var latitude: Double
    var longitude: Double
    var name: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(coordinate: CLLocationCoordinate2D, name: String = "Dropped pin") {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.name = name
    }
}
