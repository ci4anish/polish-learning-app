import SwiftUI

@main
struct YapsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color.accentColor)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Scan", systemImage: "text.viewfinder") {
                NavigationStack {
                    GrabTextView()
                }
            }

            Tab("History", systemImage: "clock") {
                NavigationStack {
                    HistoryPlaceholderView()
                }
            }
        }
    }
}

struct HistoryPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "No History Yet",
            systemImage: "clock.badge.questionmark",
            description: Text("Your scanned texts will appear here")
        )
        .navigationTitle("History")
    }
}
