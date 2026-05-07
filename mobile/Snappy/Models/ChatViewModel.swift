import Foundation

@Observable
final class ChatViewModel: @unchecked Sendable, Identifiable {
    let id = UUID()
    private(set) var messages: [ChatMessage] = []
    private(set) var isStreaming = false
    private(set) var error: String?
    private(set) var hasStarted = false

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
        guard !hasStarted else { return }
        hasStarted = true
        isStreaming = true
        error = nil

        streamTask = Task {
            await streamResponse()
        }
    }

    @MainActor
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming, hasStarted else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        isStreaming = true
        error = nil

        streamTask = Task {
            await streamResponse()
        }
    }

    func cancel() {
        streamTask?.cancel()
    }

    @MainActor
    private func snapshotHistory() -> [APIService.ChatHistoryMessage] {
        messages.map { APIService.ChatHistoryMessage(role: $0.role.rawValue, content: $0.content) }
    }

    private func streamResponse() async {
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        await MainActor.run {
            self.messages.append(assistantMessage)
        }
        let messageIndex = await MainActor.run { self.messages.count - 1 }
        let history = await snapshotHistoryExcludingLast()

        do {
            let stream = try await APIService.shared.streamChat(
                selectedText: selectedText,
                context: context,
                sourceLanguage: sourceLanguage,
                history: history
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

    @MainActor
    private func snapshotHistoryExcludingLast() -> [APIService.ChatHistoryMessage] {
        let trimmed = messages.dropLast()
        return trimmed.map { APIService.ChatHistoryMessage(role: $0.role.rawValue, content: $0.content) }
    }
}
