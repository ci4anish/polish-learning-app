import SwiftUI

@main
struct MainApp: App {
    @State private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .tint(Color.accentColor)
                .onOpenURL { url in
                    Task { await auth.handleDeepLink(url) }
                }
        }
    }
}
