import SwiftUI

struct SettingsView: View {
    @Binding var unit: SpeedUnit
    @Binding var appearance: AppearanceMode
    @Binding var travelMode: TravelMode
    @Binding var headingMode: MapHeadingMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TravelMode.allCases) { option in
                        choiceRow(
                            title: option.settingsTitle,
                            detail: option.settingsDetail,
                            selected: travelMode == option,
                            symbol: option.symbol
                        ) {
                            travelMode = option
                        }
                    }
                } header: {
                    Text("Trip")
                } footer: {
                    Text("Slide left or right to move the map. It stays where you leave it. Tap the location button to return to yourself. Pinch or slide up and down to zoom.")
                }

                Section {
                    ForEach(MapHeadingMode.allCases) { option in
                        choiceRow(
                            title: option.settingsTitle,
                            detail: option.settingsDetail,
                            selected: headingMode == option,
                            symbol: option.symbol
                        ) {
                            headingMode = option
                        }
                    }
                } header: {
                    Text("Map")
                } footer: {
                    Text("Driver view turns the map with you. North keeps north at the top.")
                }

                Section {
                    ForEach(SpeedUnit.allCases) { option in
                        choiceRow(
                            title: option.settingsTitle,
                            detail: option.settingsDetail,
                            selected: unit == option
                        ) {
                            unit = option
                        }
                    }
                } header: {
                    Text("Speed unit")
                } footer: {
                    Text("This also changes remaining distance on the map.")
                }

                Section {
                    ForEach(AppearanceMode.allCases) { option in
                        choiceRow(
                            title: option.settingsTitle,
                            detail: option.settingsDetail,
                            selected: appearance == option,
                            symbol: option.symbol
                        ) {
                            appearance = option
                        }
                    }
                } header: {
                    Text("Screen")
                } footer: {
                    Text("Day uses a light map. Night uses a dark map.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(appearance.colorScheme)
    }

    private func choiceRow(
        title: String,
        detail: String,
        selected: Bool,
        symbol: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent(appearance))
                        .frame(width: 28, height: 28)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent(appearance))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(unit: .constant(.kilometersPerHour), appearance: .constant(.night), travelMode: .constant(.drive), headingMode: .constant(.driver))
}
