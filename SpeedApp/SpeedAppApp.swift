import SwiftUI

@main
struct SpeedAppApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var cameraManager = CameraManager()

    var body: some Scene {
        WindowGroup {
            DrivingView()
                .environmentObject(locationManager)
                .environmentObject(navigationManager)
                .environmentObject(cameraManager)
        }
    }
}
