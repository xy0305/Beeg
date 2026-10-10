import SwiftUI

@main
struct BeegApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .tint(.white)
        }
    }
}
