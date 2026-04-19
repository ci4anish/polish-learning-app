import SwiftUI

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
            } else {
                Section {
                    SignInControls(auth: auth)
                } header: {
                    Text("Вхід")
                } footer: {
                    Text("Увійдіть, щоб користуватися аудіо-озвученням та AI-репетитором. Сканування та переклад працюють без входу.")
                }
            }

            Section("Локальний AI (Qwen 2.5 1.5B)") {
                LocalAIControls(
                    llm: llm,
                    useLocalAI: $useLocalAI,
                    useLocalAITranslation: $useLocalAITranslation
                )
            }

            if auth.isAuthenticated {
                Section {
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        Label("Вийти", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .navigationTitle("Профіль")
        .task { await llm.checkLocalAvailability() }
    }
}

private struct SignInControls: View {
    @Bindable var auth: AuthService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if auth.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Виконую вхід…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                        Text("Увійти через Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.black)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if let message = auth.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
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
