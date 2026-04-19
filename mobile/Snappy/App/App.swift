import SwiftUI

@main
struct MainApp: App {
    @State private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environment(auth)
            .tint(Color.accentColor)
            .animation(.default, value: auth.isAuthenticated)
            .onOpenURL { url in
                Task { await auth.handleDeepLink(url) }
            }
        }
    }
}

struct ContentView: View {
    @Environment(AuthService.self) private var auth

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

            Tab("Профіль", systemImage: "person.circle") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
    }
}

struct HistoryPlaceholderView: View {
    @State private var items: [OCRHistoryItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                ContentUnavailableView("Помилка", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if items.isEmpty {
                ContentUnavailableView(
                    "Поки що порожньо",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Тут зʼявляться ваші відскановані тексти")
                )
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink(destination: OCRHistoryDetailView(item: item)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.preview)
                                    .font(.body)
                                    .lineLimit(3)
                                HStack {
                                    Label(item.detectedLanguage.uppercased(), systemImage: "globe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(Self.dateFormatter.string(from: item.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        deleteItems(at: offsets)
                    }
                }
            }
        }
        .navigationTitle("Історія")
        .task { await loadHistory() }
        .refreshable { await loadHistory() }
    }

    private func loadHistory() async {
        isLoading = items.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await APIService.shared.fetchOCRHistory()
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)
        Task {
            for item in toDelete {
                try? await APIService.shared.deleteOCRHistory(id: item.id)
            }
        }
    }
}

struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @State private var llm = LocalLLMService.shared
    @AppStorage("useLocalAI") private var useLocalAI = false
    @AppStorage("useLocalAITranslation") private var useLocalAITranslation = false

    var body: some View {
        List {
            if let user = auth.session?.user {
                Section("Акаунт") {
                    if let email = user.email {
                        LabeledContent("Email", value: email)
                    }
                    if let name = user.userMetadata["full_name"]?.stringValue {
                        LabeledContent("Імʼя", value: name)
                    }
                    LabeledContent("ID") {
                        Text(user.id.uuidString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Локальний AI (Qwen 2.5 1.5B)") {
                LocalAIControls(
                    llm: llm,
                    useLocalAI: $useLocalAI,
                    useLocalAITranslation: $useLocalAITranslation
                )
            }

            Section {
                Button(role: .destructive) {
                    Task { await auth.signOut() }
                } label: {
                    Label("Вийти", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Профіль")
        .task { await llm.checkLocalAvailability() }
    }
}

private struct LocalAIControls: View {
    @Bindable var llm: LocalLLMService
    @Binding var useLocalAI: Bool
    @Binding var useLocalAITranslation: Bool

    var body: some View {
        switch llm.state {
        case .notDownloaded:
            VStack(alignment: .leading, spacing: 8) {
                Text("Модель ~900 МБ. Працює офлайн на пристрої.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await llm.download() }
                } label: {
                    Label("Завантажити модель", systemImage: "arrow.down.circle")
                }
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress)
                Text("Завантажую \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Завантажую модель в памʼять...")
            }
        case .ready:
            Toggle("Покращувати OCR за допомогою AI", isOn: $useLocalAI)
            Toggle("Покращувати переклади за допомогою AI", isOn: $useLocalAITranslation)
            Button(role: .destructive) {
                Task { await llm.delete() }
            } label: {
                Label("Видалити модель", systemImage: "trash")
            }
        case .error(let msg):
            VStack(alignment: .leading, spacing: 6) {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button {
                    Task { await llm.download() }
                } label: {
                    Label("Повторити", systemImage: "arrow.clockwise")
                }
            }
        case .unsupported(let msg):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct OCRHistoryDetailView: View {
    let item: OCRHistoryItem

    @State private var viewModel: OCRViewModel

    init(item: OCRHistoryItem) {
        self.item = item
        self._viewModel = State(initialValue: OCRViewModel(blocks: item.blocks, detectedLanguage: item.detectedLanguage))
    }

    var body: some View {
        PreviewerView(viewModel: viewModel)
    }
}
