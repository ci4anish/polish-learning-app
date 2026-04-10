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
            Tab("Сканувати", systemImage: "text.viewfinder") {
                NavigationStack {
                    GrabTextView()
                }
            }

            Tab("Історія", systemImage: "clock") {
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
            "Поки що порожньо",
            systemImage: "clock.badge.questionmark",
            description: Text("Тут зʼявляться ваші відскановані тексти")
        )
        .navigationTitle("Історія")
    }
}
