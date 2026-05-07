import SwiftUI

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                GrabTextView()
            }
            .tint(Color.accentColor)
        }
    }
}
