import SwiftUI
import KSPlayer

@main
struct BeegApp: App {
    @UIApplicationDelegateAdaptor(BeegAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .tint(.white)
        }
    }
}

final class BeegAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        KSOptions.supportedInterfaceOrientations ?? .portrait
    }
}
