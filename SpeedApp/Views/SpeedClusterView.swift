import CoreLocation
import SwiftUI

struct SpeedClusterView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var cameraManager: CameraManager
    @Environment(\.appearance) private var appearance

    @Binding var unit: SpeedUnit

    private var colors: Palette { Theme.palette(appearance) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpeedometerGauge(
                speed: speedValue,
                maxSpeed: unit.gaugeMaximum,
                unit: unit,
                remainingTime: liveRemainingTime,
                remainingMeters: navigationManager.hasRoute ? navigationManager.remainingDistance : 0,
                remainingDistanceText: navigationManager.hasRoute
                    ? Formatters.distance(navigationManager.remainingDistance, unit: unit)
                    : nil
            )
            .padding(.top, 20)
            .padding(.bottom, 4)

            speedBadge
                .padding(.top, 4)
                .padding(.trailing, 12)

            if let alert = cameraManager.alert {
                cameraBadge(alert)
                    .padding(.bottom, 12)
                    .padding(.leading, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .animation(.easeOut(duration: 0.28), value: speedValue)
        .animation(.easeOut(duration: 0.28), value: liveRemainingTime)
    }

    private var speedValue: Double {
        unit.value(fromMetersPerSecond: locationManager.speedMetersPerSecond)
    }

    private var liveRemainingTime: TimeInterval? {
        guard navigationManager.hasRoute else { return nil }
        let speed = locationManager.speedMetersPerSecond
        let distance = navigationManager.remainingDistance
        if speed > 1.5, distance > 0 {
            return distance / speed
        }
        return navigationManager.remainingTime
    }

    private var speedBadge: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(String(Int(speedValue.rounded())))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(colors.primary)
                .contentTransition(.numericText())
            Text(unit.label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent(appearance))
        }
    }

    private func cameraBadge(_ alert: CameraAlert) -> some View {
        let overLimit: Bool = {
            guard let limit = alert.camera.speedLimitKmh else { return false }
            return locationManager.speedMetersPerSecond * 3.6 > Double(limit) + 2
        }()
        return VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "camera.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(overLimit ? Color.red : Theme.camera(appearance), in: Circle())
            Text("\(Int(alert.distance.rounded())) m")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(colors.primary)
            if let limit = alert.camera.speedLimitKmh {
                Text("\(limit) km/h")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(overLimit ? Color.red : colors.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speed camera in \(Int(alert.distance.rounded())) meters")
    }

    private var accessibilityLabel: String {
        let speed = "\(Formatters.speed(locationManager.speedMetersPerSecond, unit: unit)) \(unit.label)"
        guard let liveRemainingTime else { return speed }
        return "\(speed), \(Formatters.eta(liveRemainingTime).accessibility) remaining at this speed, arrive \(Formatters.arrivalClock(liveRemainingTime))"
    }
}

private struct SpeedometerGauge: View {
    @Environment(\.appearance) private var appearance

    let speed: Double
    let maxSpeed: Double
    let unit: SpeedUnit
    let remainingTime: TimeInterval?
    let remainingMeters: CLLocationDistance
    let remainingDistanceText: String?

    private var colors: Palette { Theme.palette(appearance) }
    private let startDegrees = 135.0
    private let sweep = 0.75
    private let outerWidth: CGFloat = 14
    private let innerWidth: CGFloat = 5

    private var speedProgress: Double {
        min(max(speed / max(maxSpeed, 1), 0), 1)
    }

    private var speedTicks: [Int] {
        Array(stride(from: 0, through: Int(maxSpeed), by: 10))
    }

    /// Three slower and three faster marks, about 10–30 units from current speed.
    private var paceTicks: [Int] {
        guard speed >= 8 else { return [] }
        let floor = unit == .kilometersPerHour ? 30 : 20
        var slower: [Int] = []
        var faster: [Int] = []
        var slowerTick = Int((speed - 10) / 10) * 10
        while slower.count < 3, slowerTick >= floor {
            if abs(Double(slowerTick) - speed) >= 10 {
                slower.append(slowerTick)
            }
            slowerTick -= 10
        }
        var fasterTick = Int((speed + 10) / 10) * 10
        if Double(fasterTick) < speed + 10 { fasterTick += 10 }
        while faster.count < 3, fasterTick <= Int(maxSpeed) {
            if abs(Double(fasterTick) - speed) >= 10 {
                faster.append(fasterTick)
            }
            fasterTick += 10
        }
        return slower + faster
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = side / 2 - outerWidth / 2
            let innerInset = outerWidth + 3 + innerWidth / 2
            let innerRadius = side / 2 - innerInset
            let tickOuter = outerRadius - outerWidth / 2 - 1
            let labelRadius = tickOuter - 14
            let deltaRadius = labelRadius - 11

            ZStack {
                gaugeRing(progress: 1, lineWidth: outerWidth, color: colors.chipTrack, inset: outerWidth / 2)
                gaugeRing(progress: speedProgress, lineWidth: outerWidth, color: Theme.accent(appearance), inset: outerWidth / 2)

                gaugeRing(progress: 1, lineWidth: innerWidth, color: colors.chipTrack, inset: innerInset)
                if remainingTime != nil {
                    gaugeRing(progress: speedProgress, lineWidth: innerWidth, color: Theme.time(appearance), inset: innerInset)
                }

                speedTickMarks(center: center, outer: tickOuter)
                speedTickLabels(center: center, radius: labelRadius)
                paceDeltaLabels(center: center, radius: deltaRadius)

                cap(progress: speedProgress, center: center, radius: outerRadius, color: Theme.accent(appearance), size: 12)
                if remainingTime != nil {
                    cap(progress: speedProgress, center: center, radius: innerRadius, color: Theme.time(appearance), size: 7)
                }

                needle(center: center, length: innerRadius - 10, progress: speedProgress)

                arrivalReadout
                    .offset(y: side * 0.34)
            }
        }
    }

    private var arrivalReadout: some View {
        VStack(spacing: 2) {
            Text(etaHeadline)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(remainingTime == nil ? colors.tertiary : Theme.time(appearance))
                .contentTransition(.numericText())
            Text(timeCaption)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var etaHeadline: String {
        guard let remainingTime else { return "—" }
        let time = Formatters.eta(remainingTime)
        if time.hours > 0 {
            return "\(time.hours)h \(time.minutesText)m left"
        }
        return "\(time.minutes) min left"
    }

    private var timeCaption: String {
        guard let remainingTime else { return "Drive to see arrival" }
        let clock = Formatters.arrivalClock(remainingTime)
        if let remainingDistanceText {
            return "arrive \(clock)  ·  \(remainingDistanceText)"
        }
        return "arrive \(clock)"
    }

    private func paceDeltaLabels(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(paceTicks, id: \.self) { value in
            if let caption = paceCaption(for: value) {
                Text(caption.text)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(caption.faster ? Theme.accent(appearance) : colors.secondary)
                    .position(polar(center: center, radius: radius, progress: Double(value) / max(maxSpeed, 1)))
            }
        }
    }

    private func paceCaption(for tick: Int) -> (text: String, faster: Bool)? {
        guard let remainingTime, remainingMeters > 0, speed >= 8 else { return nil }
        let atSpeed = Formatters.timeIfTraveling(kilometersPerHour: kilometersPerHour(forTick: tick), remainingMeters: remainingMeters)
        let text = Formatters.signedMinutes(from: atSpeed - remainingTime)
        if text == "same" { return nil }
        return (text, atSpeed < remainingTime)
    }

    private func kilometersPerHour(forTick value: Int) -> Double {
        switch unit {
        case .kilometersPerHour: return Double(value)
        case .milesPerHour: return Double(value) * 1.609344
        }
    }

    private func gaugeRing(progress: Double, lineWidth: CGFloat, color: Color, inset: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: sweep * min(max(progress, 0), 1))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .padding(inset)
            .rotationEffect(.degrees(startDegrees))
    }

    private func needle(center: CGPoint, length: CGFloat, progress: Double) -> some View {
        Canvas { context, _ in
            let tip = polar(center: center, radius: length, progress: progress)
            let angle = (startDegrees + 360 * sweep * progress) * .pi / 180
            let px = cos(angle + .pi / 2) * 7
            let py = sin(angle + .pi / 2) * 7
            var blade = Path()
            blade.move(to: tip)
            blade.addLine(to: CGPoint(x: center.x + px, y: center.y + py))
            blade.addLine(to: CGPoint(x: center.x - px, y: center.y - py))
            blade.closeSubpath()
            context.fill(blade, with: .color(Theme.time(appearance)))
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)),
                with: .color(Theme.time(appearance))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                with: .color(colors.primary)
            )
        }
        .allowsHitTesting(false)
    }

    private func speedTickMarks(center: CGPoint, outer: CGFloat) -> some View {
        Canvas { context, _ in
            for value in speedTicks {
                let progress = Double(value) / maxSpeed
                let major = value % 20 == 0 || value == Int(maxSpeed)
                let inner = outer - (major ? 10 : 6)
                var path = Path()
                path.move(to: polar(center: center, radius: outer, progress: progress))
                path.addLine(to: polar(center: center, radius: inner, progress: progress))
                context.stroke(
                    path,
                    with: .color(colors.tertiary.opacity(major ? 0.9 : 0.55)),
                    style: StrokeStyle(lineWidth: major ? 1.6 : 1, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func speedTickLabels(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(speedTicks, id: \.self) { value in
            let progress = Double(value) / maxSpeed
            let major = value % 20 == 0 || value == Int(maxSpeed)
            Text("\(value)")
                .font(.system(size: major ? 9 : 7, weight: .semibold, design: .rounded))
                .foregroundStyle(major ? colors.secondary : colors.tertiary)
                .position(polar(center: center, radius: radius, progress: progress))
        }
    }

    private func cap(progress: Double, center: CGPoint, radius: CGFloat, color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Circle().stroke(colors.primary.opacity(0.9), lineWidth: 2)
            }
            .position(polar(center: center, radius: radius, progress: progress))
    }

    private func polar(center: CGPoint, radius: CGFloat, progress: Double) -> CGPoint {
        let degrees = startDegrees + 360 * sweep * progress
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }
}

private extension SpeedUnit {
    var gaugeMaximum: Double {
        switch self {
        case .kilometersPerHour: return 170
        case .milesPerHour: return 110
        }
    }
}
