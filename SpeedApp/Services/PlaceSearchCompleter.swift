import Combine
import Foundation
import MapKit

@MainActor
final class PlaceSearchCompleter: NSObject, ObservableObject {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.pointOfInterestFilter = .includingAll
    }

    func updateRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func search(completion: MKLocalSearchCompletion) async -> MKMapItem? {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }

    func searchFreeText(_ text: String, in region: MKCoordinateRegion) async -> MKMapItem? {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = region
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }
}

extension PlaceSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let items = completer.results
        Task { @MainActor in
            results = items
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            results = []
        }
    }
}
