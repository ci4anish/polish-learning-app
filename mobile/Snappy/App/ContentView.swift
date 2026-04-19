import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        TabView {
            Tab("Сканувати", systemImage: "text.viewfinder") {
                NavigationStack {
                    GrabTextView()
                }
            }

            Tab("Профіль", systemImage: "person.circle") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
    }
}
