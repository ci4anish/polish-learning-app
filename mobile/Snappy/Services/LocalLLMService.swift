import Foundation
import SwiftUI
@preconcurrency import Hub
import MLX
import MLXLLM
import MLXLMCommon

enum LocalLLMModel: String, CaseIterable, Identifiable, Sendable, Hashable {
    case qwen2_5_1_5B
    case qwen2_5_3B
    case llama3_2_3B
    case translateGemma_4B

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen2_5_1_5B:    return "Qwen 2.5 · 1.5B"
        case .qwen2_5_3B:      return "Qwen 2.5 · 3B"
        case .llama3_2_3B:     return "Llama 3.2 · 3B"
        case .translateGemma_4B: return "TranslateGemma · 4B"
        }
    }

    /// Approximate on-disk size after 4-bit quantisation.
    var approximateSize: String {
        switch self {
        case .qwen2_5_1_5B:    return "~900 МБ"
        case .qwen2_5_3B:      return "~1.8 ГБ"
        case .llama3_2_3B:     return "~2 ГБ"
        case .translateGemma_4B: return "~2.2 ГБ"
        }
    }

    /// Short hint about what this model is best at — shown in the UI.
    var purposeHint: String {
        switch self {
        case .qwen2_5_1_5B:    return "Швидка, для простих задач"
        case .qwen2_5_3B:      return "Універсальна"
        case .llama3_2_3B:     return "Універсальна"
        case .translateGemma_4B: return "Спеціально для перекладу"
        }
    }

    var configuration: ModelConfiguration {
        switch self {
        case .qwen2_5_1_5B:
            return LLMRegistry.qwen2_5_1_5b
        case .qwen2_5_3B:
            return ModelConfiguration(
                id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                defaultPrompt: "Why is the sky blue?"
            )
        case .llama3_2_3B:
            return LLMRegistry.llama3_2_3B_4bit
        case .translateGemma_4B:
            return ModelConfiguration(
                id: "mlx-community/translategemma-4b-it-4bit",
                defaultPrompt: "Translate to English: Witaj świecie."
            )
        }
    }
}

@MainActor
@Observable
final class LocalLLMService {
    static let shared = LocalLLMService()

    enum ModelStatus: Sendable, Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case loading
        case ready                       // downloaded AND currently loaded in memory
        case downloaded                  // on disk, not currently in memory
        case error(String)
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static let unsupportedMessage = "Локальний AI працює лише на реальному пристрої (iPhone/iPad). MLX потребує Metal-підтримки, якої немає в iOS Simulator."
    private static let ocrModelKey = "selectedOCRModel"
    private static let translationModelKey = "selectedTranslationModel"

    /// Model used by `classify(blocks:)`.
    private(set) var ocrModel: LocalLLMModel
    /// Model used by `enhanceTranslation(...)`.
    private(set) var translationModel: LocalLLMModel

    /// Per-model state. Reflects disk presence + in-memory load + ongoing
    /// download/load tasks.
    private(set) var statuses: [LocalLLMModel: ModelStatus] = [:]

    /// Set on simulator (or other non-Metal environments). When non-nil,
    /// the UI should show this message and disable all download/load actions.
    private(set) var unsupportedReason: String?

    private let hub: HubApi

    /// The model currently held in memory (if any).
    private var loadedModel: LocalLLMModel?
    private var container: ModelContainer?

    /// In-flight load (which may include a download). Only one at a time —
    /// switching models cancels the previous task.
    private var loadTask: (model: LocalLLMModel, task: Task<ModelContainer, Error>)?

    private init() {
        let base = URL.cachesDirectory.appending(path: "huggingface")
        self.hub = HubApi(downloadBase: base)

        let storedOcr = UserDefaults.standard.string(forKey: Self.ocrModelKey)
        let storedTrans = UserDefaults.standard.string(forKey: Self.translationModelKey)
        self.ocrModel = storedOcr.flatMap(LocalLLMModel.init(rawValue:)) ?? .qwen2_5_1_5B
        self.translationModel = storedTrans.flatMap(LocalLLMModel.init(rawValue:)) ?? .qwen2_5_1_5B
    }

    // MARK: - Public API

    func status(for model: LocalLLMModel) -> ModelStatus {
        statuses[model] ?? .notDownloaded
    }

    /// Refreshes per-model availability from disk. Does NOT load anything.
    /// Active states (downloading / loading / ready) are preserved.
    func refreshAvailability() async {
        if Self.isSimulator {
            unsupportedReason = Self.unsupportedMessage
            return
        }
        unsupportedReason = nil
        for model in LocalLLMModel.allCases {
            switch statuses[model] {
            case .downloading, .loading, .ready, .error:
                continue
            default:
                statuses[model] = hasLocalSnapshot(for: model) ? .downloaded : .notDownloaded
            }
        }
    }

    func selectOCRModel(_ model: LocalLLMModel) {
        guard model != ocrModel else { return }
        ocrModel = model
        UserDefaults.standard.set(model.rawValue, forKey: Self.ocrModelKey)
    }

    func selectTranslationModel(_ model: LocalLLMModel) {
        guard model != translationModel else { return }
        translationModel = model
        UserDefaults.standard.set(model.rawValue, forKey: Self.translationModelKey)
    }

    /// Downloads (and loads into memory) the given model.
    func download(_ model: LocalLLMModel) async {
        if Self.isSimulator {
            unsupportedReason = Self.unsupportedMessage
            return
        }
        do {
            _ = try await ensureLoaded(for: model)
        } catch {
            NSLog("[LocalLLMService] download(%@) error: %@", model.rawValue, String(describing: error))
        }
    }

    /// Deletes the model snapshot from disk. If the model is currently loaded
    /// in memory, it is unloaded first.
    func delete(_ model: LocalLLMModel) async {
        if loadedModel == model {
            loadTask?.task.cancel()
            loadTask = nil
            container = nil
            loadedModel = nil
        }
        let dir = model.configuration.modelDirectory(hub: hub)
        try? FileManager.default.removeItem(at: dir)
        statuses[model] = Self.isSimulator ? .error(Self.unsupportedMessage) : .notDownloaded
    }

    // MARK: - Inference

    /// Classifies each block as `.heading` or `.paragraph` using the OCR model.
    func classify(blocks: [TextBlock]) async throws -> [TextBlock] {
        guard !blocks.isEmpty else { return blocks }
        let container = try await ensureLoaded(for: ocrModel)

        let systemPrompt = LLMEnhancementPrompt.classificationSystemPrompt
        let userPrompt = LLMEnhancementPrompt.classificationUserPrompt(for: blocks)
        let maxOutput = blocks.count + 16

        let raw = try await container.perform { (context: ModelContext) -> String in
            let chat: [Chat.Message] = [
                .system(systemPrompt),
                .user(userPrompt),
            ]
            let userInput = UserInput(chat: chat)
            let lmInput = try await context.processor.prepare(input: userInput)
            let parameters = GenerateParameters(
                maxTokens: maxOutput,
                temperature: 0.0,
                topP: 1.0
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

        NSLog("[LocalLLMService] classify raw output: %@", raw.trimmingCharacters(in: .whitespacesAndNewlines))

        let types = LLMEnhancementPrompt.parseClassification(raw, expectedCount: blocks.count)
        return zip(blocks, types).map { block, type in
            TextBlock(type: type, relativeHeight: block.relativeHeight, original: block.original)
        }
    }

    func enhanceTranslation(
        selection: String,
        context: String?,
        draft: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> String {
        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSelection.isEmpty else { return draft }

        let container = try await ensureLoaded(for: translationModel)

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

    // MARK: - Internals

    private func hasLocalSnapshot(for model: LocalLLMModel) -> Bool {
        let dir = model.configuration.modelDirectory(hub: hub)
        let configURL = dir.appending(path: "config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else { return false }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            return contents.contains { $0.hasSuffix(".safetensors") }
        }
        return false
    }

    /// Ensures the requested model is loaded into memory. If a different model
    /// is currently loaded (or being loaded), it is dropped/cancelled first —
    /// only one model lives in memory at a time.
    private func ensureLoaded(for model: LocalLLMModel) async throws -> ModelContainer {
        if Self.isSimulator {
            unsupportedReason = Self.unsupportedMessage
            throw NSError(domain: "LocalLLMService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: Self.unsupportedMessage])
        }

        if loadedModel == model, let container { return container }

        if let pending = loadTask, pending.model == model {
            return try await pending.task.value
        }

        if let pending = loadTask {
            pending.task.cancel()
            loadTask = nil
        }
        if let previous = loadedModel, previous != model {
            statuses[previous] = hasLocalSnapshot(for: previous) ? .downloaded : .notDownloaded
        }
        loadedModel = nil
        container = nil

        statuses[model] = hasLocalSnapshot(for: model)
            ? .loading
            : .downloading(progress: 0)

        let task = Task<ModelContainer, Error> { [hub] in
            MLX.GPU.set(cacheLimit: 32 * 1024 * 1024)
            let factory = LLMModelFactory.shared
            return try await factory.loadContainer(
                hub: hub, configuration: model.configuration
            ) { progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    if case .downloading = LocalLLMService.shared.statuses[model] {
                        LocalLLMService.shared.statuses[model] = .downloading(progress: fraction)
                    }
                }
            }
        }
        loadTask = (model: model, task: task)

        do {
            let container = try await task.value
            self.container = container
            self.loadedModel = model
            self.loadTask = nil
            self.statuses[model] = .ready
            return container
        } catch {
            self.loadTask = nil
            self.statuses[model] = .error(error.localizedDescription)
            throw error
        }
    }
}
