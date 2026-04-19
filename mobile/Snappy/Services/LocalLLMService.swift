import Foundation
import SwiftUI
@preconcurrency import Hub
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
@Observable
final class LocalLLMService {
    static let shared = LocalLLMService()

    enum State: Sendable, Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case loading
        case ready
        case error(String)
        case unsupported(String)
    }

    private(set) var state: State = .notDownloaded

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static let unsupportedMessage = "Локальний AI працює лише на реальному пристрої (iPhone/iPad). MLX потребує Metal-підтримки, якої немає в iOS Simulator."

    private let configuration = LLMRegistry.qwen2_5_1_5b
    private let hub: HubApi

    private var container: ModelContainer?
    private var loadTask: Task<ModelContainer, Error>?

    private init() {
        let base = URL.cachesDirectory.appending(path: "huggingface")
        self.hub = HubApi(downloadBase: base)
    }

    func checkLocalAvailability() async {
        if Self.isSimulator {
            state = .unsupported(Self.unsupportedMessage)
            return
        }
        if container != nil { state = .ready; return }
        if hasLocalSnapshot() {
            state = .loading
            do {
                _ = try await ensureLoaded()
                state = .ready
            } catch {
                state = .error(error.localizedDescription)
            }
        } else {
            state = .notDownloaded
        }
    }

    func download() async {
        if Self.isSimulator {
            state = .unsupported(Self.unsupportedMessage)
            return
        }
        if container != nil { state = .ready; return }
        state = .downloading(progress: 0)
        do {
            _ = try await ensureLoaded()
            state = .ready
        } catch {
            NSLog("[LocalLLMService] download error: %@", String(describing: error))
            state = .error(error.localizedDescription)
        }
    }

    func delete() async {
        loadTask?.cancel()
        loadTask = nil
        container = nil
        let dir = configuration.modelDirectory(hub: hub)
        try? FileManager.default.removeItem(at: dir)
        state = Self.isSimulator ? .unsupported(Self.unsupportedMessage) : .notDownloaded
    }

    func enhance(blocks: [TextBlock], language: String) async throws -> [TextBlock] {
        guard !blocks.isEmpty else { return blocks }
        if Self.isSimulator {
            throw NSError(domain: "LocalLLMService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: Self.unsupportedMessage])
        }
        let container = try await ensureLoaded()

        let userPrompt = LLMEnhancementPrompt.userPrompt(for: blocks, language: language)
        let systemPrompt = LLMEnhancementPrompt.systemPrompt

        let raw = try await container.perform { (context: ModelContext) -> String in
            let chat: [Chat.Message] = [
                .system(systemPrompt),
                .user(userPrompt),
            ]
            let userInput = UserInput(chat: chat)
            let lmInput = try await context.processor.prepare(input: userInput)
            let parameters = GenerateParameters(
                maxTokens: 2048,
                temperature: 0.2,
                topP: 0.9
            )
            let stream = try MLXLMCommon.generate(
                input: lmInput, parameters: parameters, context: context)

            var output = ""
            for await event in stream {
                if let chunk = event.chunk {
                    output += chunk
                }
            }
            return output
        }

        return try LLMEnhancementPrompt.parseResponse(raw, sourceBlocks: blocks)
    }

    func enhanceTranslation(
        selection: String,
        context: String?,
        draft: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> String {
        if Self.isSimulator {
            throw NSError(domain: "LocalLLMService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: Self.unsupportedMessage])
        }
        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSelection.isEmpty else { return draft }

        let container = try await ensureLoaded()

        let systemPrompt = LLMEnhancementPrompt.translationSystemPrompt
        let userPrompt = LLMEnhancementPrompt.translationUserPrompt(
            selection: trimmedSelection,
            context: context,
            draft: draft,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        let raw = try await container.perform { (context: ModelContext) -> String in
            let chat: [Chat.Message] = [
                .system(systemPrompt),
                .user(userPrompt),
            ]
            let userInput = UserInput(chat: chat)
            let lmInput = try await context.processor.prepare(input: userInput)
            let parameters = GenerateParameters(
                maxTokens: 256,
                temperature: 0.2,
                topP: 0.9
            )
            let stream = try MLXLMCommon.generate(
                input: lmInput, parameters: parameters, context: context)

            var output = ""
            for await event in stream {
                if let chunk = event.chunk {
                    output += chunk
                }
            }
            return output
        }

        let cleaned = LLMEnhancementPrompt.sanitizeTranslation(raw)
        return cleaned.isEmpty ? draft : cleaned
    }

    private func hasLocalSnapshot() -> Bool {
        let dir = configuration.modelDirectory(hub: hub)
        let configURL = dir.appending(path: "config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else { return false }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            return contents.contains { $0.hasSuffix(".safetensors") }
        }
        return false
    }

    private func ensureLoaded() async throws -> ModelContainer {
        if let container { return container }
        if let loadTask {
            return try await loadTask.value
        }
        let task = Task<ModelContainer, Error> { [hub, configuration] in
            MLX.GPU.set(cacheLimit: 32 * 1024 * 1024)
            let factory = LLMModelFactory.shared
            let container = try await factory.loadContainer(
                hub: hub, configuration: configuration
            ) { progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    if case .downloading = LocalLLMService.shared.state {
                        LocalLLMService.shared.state = .downloading(progress: fraction)
                    } else if case .notDownloaded = LocalLLMService.shared.state {
                        LocalLLMService.shared.state = .downloading(progress: fraction)
                    }
                }
            }
            return container
        }
        loadTask = task
        do {
            let container = try await task.value
            self.container = container
            self.loadTask = nil
            return container
        } catch {
            self.loadTask = nil
            throw error
        }
    }
}
