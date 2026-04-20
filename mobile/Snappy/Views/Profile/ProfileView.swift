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

            if let reason = llm.unsupportedReason {
                Section("Локальний AI") {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    LLMFeatureControls(
                        llm: llm,
                        selection: llm.ocrModel,
                        onSelect: { llm.selectOCRModel($0) },
                        isEnabled: $useLocalAI,
                        enableLabel: "Покращувати OCR за допомогою AI"
                    )
                } header: {
                    Text("Локальний AI · OCR")
                } footer: {
                    Text("Модель класифікує блоки тексту (заголовок чи абзац). Достатньо найменшої моделі.")
                }

                Section {
                    LLMFeatureControls(
                        llm: llm,
                        selection: llm.translationModel,
                        onSelect: { llm.selectTranslationModel($0) },
                        isEnabled: $useLocalAITranslation,
                        enableLabel: "Покращувати переклади за допомогою AI"
                    )
                } header: {
                    Text("Локальний AI · Переклад")
                } footer: {
                    Text("TranslateGemma · 4B — спеціалізована модель Google для перекладу 55 мовами. У памʼяті одночасно тримається лише одна модель: якщо OCR і переклад використовують різні — між ними буде перезавантаження.")
                }

                Section {
                    ForEach(LocalLLMModel.allCases) { model in
                        DownloadedModelRow(llm: llm, model: model)
                    }
                } header: {
                    Text("Моделі на пристрої")
                }
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
        .task { await llm.refreshAvailability() }
    }
}

// MARK: - Sign-in

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

// MARK: - Per-feature controls

private struct LLMFeatureControls: View {
    @Bindable var llm: LocalLLMService
    let selection: LocalLLMModel
    let onSelect: (LocalLLMModel) -> Void
    @Binding var isEnabled: Bool
    let enableLabel: String

    private var status: LocalLLMService.ModelStatus { llm.status(for: selection) }

    var body: some View {
        Picker("Модель", selection: Binding(
            get: { selection },
            set: { onSelect($0) }
        )) {
            ForEach(LocalLLMModel.allCases) { model in
                HStack {
                    Text(model.displayName)
                    if case .downloaded = llm.status(for: model) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if case .ready = llm.status(for: model) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .tag(model)
            }
        }

        Text(selection.purposeHint + " · " + selection.approximateSize)
            .font(.caption)
            .foregroundStyle(.secondary)

        statusBody
    }

    @ViewBuilder
    private var statusBody: some View {
        switch status {
        case .notDownloaded:
            Button {
                Task { await llm.download(selection) }
            } label: {
                Label("Завантажити модель", systemImage: "arrow.down.circle")
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress)
                Text("Завантажую — \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Завантажую модель в памʼять…")
            }
        case .downloaded:
            VStack(alignment: .leading, spacing: 8) {
                Text("Завантажена. Буде підвантажена в памʼять при першому запиті.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(enableLabel, isOn: $isEnabled)
            }
        case .ready:
            Toggle(enableLabel, isOn: $isEnabled)
        case .error(let msg):
            VStack(alignment: .leading, spacing: 6) {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button {
                    Task { await llm.download(selection) }
                } label: {
                    Label("Повторити", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

// MARK: - Downloaded models management

private struct DownloadedModelRow: View {
    @Bindable var llm: LocalLLMService
    let model: LocalLLMModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.subheadline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            actionView
        }
    }

    private var statusText: String {
        switch llm.status(for: model) {
        case .notDownloaded: return model.approximateSize
        case .downloading(let p): return "Завантажую \(Int(p * 100))%"
        case .loading: return "Завантажую в памʼять…"
        case .downloaded: return "На пристрої · \(model.approximateSize)"
        case .ready: return "В памʼяті · \(model.approximateSize)"
        case .error: return "Помилка"
        }
    }

    @ViewBuilder
    private var actionView: some View {
        switch llm.status(for: model) {
        case .notDownloaded, .error:
            Button {
                Task { await llm.download(model) }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
        case .downloading, .loading:
            ProgressView()
        case .downloaded, .ready:
            Button(role: .destructive) {
                Task { await llm.delete(model) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
