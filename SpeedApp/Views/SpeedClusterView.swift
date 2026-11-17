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
            VStack(spacing: 10) {
                SpeedometerGauge(
                    speed: speedValue,
                    maxSpeed: unit.gaugeMaximum,
                    unit: unit,
                    remainingTime: liveRemainingTime,
                    remainingMeters: navigationManager.hasRoute ? navigationManager.remainingDistance : 0
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 8)

                paceStrip

                arrivalReadout
                    .padding(.bottom, 4)
            }

            speedBadge
                .padding(.top, 4)
                .padding(.trailing, 12)

            if let alert = cameraManager.alert {
                cameraBadge(alert)
                    .padding(.top, 4)
                    .padding(.leading, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if let side = navigationManager.nextTurnSide, navigationManager.hasRoute {
                turnSign(side)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private func turnSign(_ side: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: side == "right" ? "arrow.turn.up.right" : "arrow.turn.up.left")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(appearance == .night ? Color(red: 0.02, green: 0.06, blue: 0.09) : .white)
                .frame(width: 56, height: 56)
                .background(Theme.accent(appearance), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(Formatters.distance(navigationManager.distanceToManeuver, unit: unit))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(colors.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(side == "right" ? "Turn right" : "Turn left") in \(Formatters.distance(navigationManager.distanceToManeuver, unit: unit))")
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

    /// Current speed in the middle, time gained or lost at 10 / 20 / 30 units either side.
    private var paceStrip: some View {
        let current = Int(speedValue.rounded())
        return HStack(spacing: 4) {
            ForEach([-30, -20, -10, 0, 10, 20, 30], id: \.self) { offset in
                paceCell(offset: offset, current: current)
            }
        }
    }

    private var paceNowText: Color {
        appearance == .day ? .white : Color(red: 0.02, green: 0.06, blue: 0.09)
    }

    private func paceCell(offset: Int, current: Int) -> some View {
        let value = min(Int(unit.gaugeMaximum), max(0, current + offset))
        let isNow = offset == 0
        let faster = offset > 0
        return VStack(spacing: 2) {
            Text(paceDeltaText(at: value, isNow: isNow, current: current))
                .font(.system(size: isNow ? 16 : 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isNow ? paceNowText : (faster ? Theme.accent(appearance) : colors.secondary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(isNow ? unit.label : (offset > 0 ? "+\(offset)" : "\(offset)"))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isNow ? paceNowText.opacity(0.75) : colors.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(isNow ? Theme.accent(appearance) : colors.chipTrack, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func paceDeltaText(at value: Int, isNow: Bool, current: Int) -> String {
        if isNow { return "\(current)" }
        guard let liveRemainingTime, navigationManager.remainingDistance > 0, speedValue >= 1, value > 0 else {
            return "—"
        }
        let atSpeed = Formatters.timeIfTraveling(
            kilometersPerHour: kilometersPerHour(forDisplayed: value),
            remainingMeters: navigationManager.remainingDistance
        )
        let text = Formatters.signedMinutes(from: atSpeed - liveRemainingTime)
        return text == "same" ? "0m" : text
    }

    private func kilometersPerHour(forDisplayed value: Int) -> Double {
        switch unit {
        case .kilometersPerHour: return Double(value)
        case .milesPerHour: return Double(value) * 1.609344
        }
    }

    private var arrivalReadout: some View {
        VStack(spacing: 2) {
            Text(etaHeadline)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(liveRemainingTime == nil ? colors.tertiary : Theme.time(appearance))
                .contentTransition(.numericText())
            Text(timeCaption)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var etaHeadline: String {
        guard let liveRemainingTime else { return "—" }
        let time = Formatters.eta(liveRemainingTime)
        if time.hours > 0 {
            return "\(time.hours)h \(time.minutesText)m left"
        }
        return "\(time.minutes) min left"
    }

    private var timeCaption: String {
        guard let liveRemainingTime else { return "Drive to see arrival" }
        let clock = Formatters.arrivalClock(liveRemainingTime)
        guard navigationManager.hasRoute else { return "arrive \(clock)" }
        let distance = Formatters.distance(navigationManager.remainingDistance, unit: unit)
        return "arrive \(clock)  ·  \(distance)"
    }

    private var accessibilityLabel: String {
        let speed = "\(Formatters.speed(locationManager.speedMetersPerSecond, unit: unit)) \(unit.label)"
        guard let liveRemainingTime else { return speed }
        return "\(speed), \(Formatters.eta(liveRemainingTime).accessibility) remaining at this speed, arrive \(Formatters.arrivalClock(liveRemainingTime))"
    }
}

private struct PaceLabel: Identifiable {
    let value: Int
    let text: String
    let faster: Bool
    var progress: Double
    var id: Int { value }
}

private struct SpeedometerGauge: View {
    @Environment(\.appearance) private var appearance

    let speed: Double
    let maxSpeed: Double
    let unit: SpeedUnit
    let remainingTime: TimeInterval?
    let remainingMeters: CLLocationDistance

    private var colors: Palette { Theme.palette(appearance) }
    private let startDegrees = 135.0
    private let sweep = 0.75
    private let ringWidth: CGFloat = 8
    /// Reference gauge size the label sizes were designed for.
    private let referenceSide: CGFloat = 320

    private var speedProgress: Double {
        min(max(speed / max(maxSpeed, 1), 0), 1)
    }

    private var speedTicks: [Int] {
        Array(stride(from: 0, through: Int(maxSpeed), by: 10))
    }

    /// Three slower and three faster marks, about 10–30 units from current speed.
    private var paceTicks: [Int] {
        guard speed.isFinite, speed >= 8 else { return [] }
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
            let width = geo.size.width.isFinite ? geo.size.width : 0
            let height = geo.size.height.isFinite ? geo.size.height : 0
            let side = min(max(width, 0), max(height, 0))
            let center = CGPoint(x: width / 2, y: height / 2)
            // Room outside the ring for the time values, which stay on one circle.
            let margin = 28 * max(side / referenceSide, 1)
            let ringRadius = side / 2 - margin - ringWidth / 2
            let tickOuter = ringRadius - ringWidth / 2 - 4
            let labelRadius = tickOuter - 16
            let deltaRadius = ringRadius + ringWidth / 2 + 16 * max(side / referenceSide, 1)
            let fontScale = max(side / referenceSide, 1)
            let ringFits = side > 40 && ringRadius > 8 && ringRadius.isFinite && deltaRadius.isFinite

            ZStack {
                if ringFits {
                gaugeRing(progress: 1, lineWidth: ringWidth, color: colors.chipTrack, radiusInset: side / 2 - ringRadius)
                if remainingTime != nil {
                    gaugeRing(progress: speedProgress, lineWidth: ringWidth, color: Theme.time(appearance), radiusInset: side / 2 - ringRadius)
                }

                speedTickMarks(center: center, outer: tickOuter)
                speedTickLabels(center: center, radius: labelRadius, fontScale: fontScale)
                paceDeltaLabels(center: center, radius: deltaRadius, fontScale: fontScale)

                if remainingTime != nil {
                    cap(progress: speedProgress, center: center, radius: ringRadius, color: Theme.time(appearance), size: 16)
                }

                needle(center: center, length: max(ringRadius - 18, 0), progress: speedProgress)
                }
            }
        }
    }

    private func paceDeltaLabels(center: CGPoint, radius: CGFloat, fontScale: CGFloat) -> some View {
        let placed = spreadPaceLabels()
        return ForEach(placed) { item in
            Text(item.text)
                .font(.system(size: 11 * fontScale, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(item.faster ? Theme.accent(appearance) : colors.secondary)
                .position(polar(center: center, radius: radius, progress: item.progress))
        }
    }

    /// Time labels share one radius. Neighbours that would overlap are walked along the arc.
    private func spreadPaceLabels() -> [PaceLabel] {
        var items: [PaceLabel] = []
        for value in paceTicks {
            guard let caption = paceCaption(for: value) else { continue }
            items.append(PaceLabel(value: value, text: caption.text, faster: caption.faster, progress: Double(value) / max(maxSpeed, 1)))
        }
        items.sort { $0.progress < $1.progress }
        // Swift traps on 1..<0. Standing still, or with no route, leaves this list empty.
        guard items.count > 1 else { return items }
        func width(_ text: String) -> Double { max(30, Double(text.count) * 6.6) }
        for index in 1..<items.count {
            let need = (width(items[index - 1].text) + width(items[index].text)) / 2 + 4
            let gap = 2 * asin(min(0.95, need / (2 * 142))) * 180 / .pi
            let minProgress = gap / (360 * sweep)
            if items[index].progress < items[index - 1].progress + minProgress {
                items[index].progress = items[index - 1].progress + minProgress
            }
        }
        if let last = items.last, last.progress > 1 {
            let overflow = last.progress - 1
            for index in items.indices {
                items[index].progress = max(0, items[index].progress - overflow)
            }
        }
        return items
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

    private func gaugeRing(progress: Double, lineWidth: CGFloat, color: Color, radiusInset: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: sweep * min(max(progress, 0), 1))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .padding(radiusInset)
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

    private func speedTickLabels(center: CGPoint, radius: CGFloat, fontScale: CGFloat) -> some View {
        ForEach(speedTicks, id: \.self) { value in
            let progress = Double(value) / maxSpeed
            let major = value % 20 == 0 || value == Int(maxSpeed)
            Text("\(value)")
                .font(.system(size: (major ? 9 : 7) * fontScale, weight: .semibold, design: .rounded))
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
