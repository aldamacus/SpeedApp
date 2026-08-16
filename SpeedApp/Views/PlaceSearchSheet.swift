import MapKit
import SwiftUI

struct PlaceSearchSheet: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var navigationManager: NavigationManager
    @Environment(\.dismiss) private var dismiss
    @Binding var travelMode: TravelMode

    @StateObject private var search = PlaceSearchCompleter()
    @State private var errorText: String?
    @State private var detent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Trip", selection: $travelMode) {
                        ForEach(TravelMode.allCases) { mode in
                            Text(mode.settingsTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20))
                }

                if search.results.isEmpty && search.query.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 24, leading: 8, bottom: 24, trailing: 8))
                        .listRowBackground(Color.clear)
                }

                if !search.results.isEmpty {
                    Section {
                        ForEach(Array(search.results.enumerated()), id: \.offset) { _, result in
                            Button {
                                Task { await choose(result) }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Destination")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Address, place, or road")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        Task { await chooseFreeText(search.query) }
                    }
                    .fontWeight(.semibold)
                    .disabled(search.query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let location = locationManager.location {
                    search.updateRegion(
                        MKCoordinateRegion(
                            center: location.coordinate,
                            latitudinalMeters: 40_000,
                            longitudinalMeters: 40_000
                        )
                    )
                }
            }
            .overlay {
                if search.isSearching {
                    ProgressView("Finding place…")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Search a destination")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(emptyDetail)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var emptyDetail: String {
        if let street = locationManager.currentStreet {
            return "You are near \(street). Type an address, place, or road."
        }
        return "Type an address, place, or road to get a \(travelMode.settingsTitle.lowercased()) route and arrival time."
    }

    private func choose(_ completion: MKLocalSearchCompletion) async {
        errorText = nil
        guard let item = await search.search(completion: completion) else {
            errorText = "Could not open that place."
            return
        }
        navigationManager.setDestination(item, from: locationManager.location)
        dismiss()
    }

    private func chooseFreeText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorText = nil
        let region: MKCoordinateRegion
        if let location = locationManager.location {
            region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        } else {
            region = MKCoordinateRegion()
        }
        guard let item = await search.searchFreeText(trimmed, in: region) else {
            errorText = "No matching destination found."
            return
        }
        navigationManager.setDestination(item, from: locationManager.location)
        dismiss()
    }
}
