import Foundation

@Observable
final class ChatViewModel: @unchecked Sendable, Identifiable {
    let id = UUID()
    private(set) var messages: [ChatMessage] = []
    private(set) var threadId: String?
    private(set) var isStreaming = false
    private(set) var error: String?

    var inputText = ""

    private let selectedText: String
    private let context: String?
    private let sourceLanguage: String?
    private var streamTask: Task<Void, Never>?

    init(selectedText: String, context: String?, sourceLanguage: String?) {
        self.selectedText = selectedText
        self.context = context
        self.sourceLanguage = sourceLanguage
    }

    @MainActor
    func startChat() {
        guard threadId == nil else { return }
        isStreaming = true
        error = nil

        streamTask = Task {
            do {
                let id = try await APIService.shared.chatStart(
                    text: selectedText,
                    context: context,
                    sourceLanguage: sourceLanguage
                )

                await MainActor.run { self.threadId = id }

                let initialPrompt = buildInitialPrompt()
                await streamResponse(for: initialPrompt)
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isStreaming = false
                }
            }
        }
    }

    @MainActor
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming, threadId != nil else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        isStreaming = true
        error = nil

        streamTask = Task {
            await streamResponse(for: text)
        }
    }

    func cancel() {
        streamTask?.cancel()
    }

    private func buildInitialPrompt() -> String {
        var parts: [String] = []
        if let lang = sourceLanguage { parts.append("Мова тексту: \(lang)") }
        if let ctx = context, ctx != selectedText { parts.append("Контекст: «\(ctx)»") }
        parts.append("Виділений текст: «\(selectedText)»")
        parts.append("Привітай мене коротко і поясни граматику виділеного тексту.")
        return parts.joined(separator: "\n")
    }

    private func streamResponse(for message: String) async {
        guard let threadId else { return }

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        await MainActor.run {
            self.messages.append(assistantMessage)
        }
        let messageIndex = await MainActor.run { self.messages.count - 1 }

        do {
            let stream = try await APIService.shared.streamChatMessage(
                threadId: threadId,
                message: message
            )

            for try await chunk in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.messages[messageIndex].content += chunk
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self.messages[messageIndex].content.isEmpty {
                    self.messages.removeLast()
                }
                self.error = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isStreaming = false
        }
    }
}
