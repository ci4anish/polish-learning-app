import Foundation

actor APIService {
    static let shared = APIService()

    private let baseURL = AppConfig.apiBaseURL

    enum APIError: LocalizedError {
        case invalidResponse
        case serverError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Invalid server response"
            case .serverError(let msg): msg
            case .networkError(let err): err.localizedDescription
            }
        }
    }

    func translate(imageData: Data, languageHint: String? = nil) async throws -> TranslationResult {
        let url = URL(string: "\(baseURL)/api/ocr")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        body.appendMultipart(boundary: boundary, name: "image", filename: "photo.jpg", mimeType: "image/jpeg", data: imageData)

        if let hint = languageHint {
            body.appendMultipart(boundary: boundary, name: "languageHint", value: hint)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(TranslationResponse.self, from: data)

        if !decoded.success || decoded.content == nil {
            throw APIError.serverError(decoded.error ?? "Translation failed (HTTP \(http.statusCode))")
        }

        return TranslationResult(id: UUID(), content: decoded.content!)
    }

    enum OCRStreamEvent {
        case meta(detectedLanguage: String)
        case block(TextBlock)
        case error(String)
        case done
    }

    func streamOCR(imageData: Data, languageHint: String? = nil) async throws -> AsyncThrowingStream<OCRStreamEvent, Error> {
        let url = URL(string: "\(baseURL)/api/ocr/stream")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "image", filename: "photo.jpg", mimeType: "image/jpeg", data: imageData)
        if let hint = languageHint {
            body.appendMultipart(boundary: boundary, name: "languageHint", value: hint)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError("OCR stream failed")
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8) else { continue }
                        Self.parseNDJSONLine(data, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func parseNDJSONLine(
        _ data: Data,
        continuation: AsyncThrowingStream<OCRStreamEvent, Error>.Continuation
    ) {
        struct Envelope: Decodable {
            let event: String
            let detectedLanguage: String?
            let block: TextBlock?
            let error: String?
        }

        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }

        switch envelope.event {
        case "meta":
            if let lang = envelope.detectedLanguage {
                continuation.yield(.meta(detectedLanguage: lang))
            }
        case "block":
            if let block = envelope.block {
                continuation.yield(.block(block))
            }
        case "error":
            continuation.yield(.error(envelope.error ?? "Unknown error"))
        case "done":
            continuation.yield(.done)
        default:
            break
        }
    }

    private struct ErrorResponse: Decodable { let error: String? }

    private struct TranslateRequest: Encodable {
        let text: String
        let context: String?
        let sourceLanguage: String?
    }

    private struct TranslateResponse: Decodable {
        let success: Bool
        let translated: String?
        let error: String?
    }

    func translateText(text: String, context: String? = nil, sourceLanguage: String? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/api/translate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(
            TranslateRequest(text: text, context: context, sourceLanguage: sourceLanguage)
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(TranslateResponse.self, from: data)

        guard decoded.success, let translated = decoded.translated else {
            throw APIError.serverError(decoded.error ?? "Translation failed (HTTP \(http.statusCode))")
        }

        return translated
    }

    func getAudio(text: String, language: String = "Polish") async throws -> Data {
        let url = URL(string: "\(baseURL)/api/audio")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct AudioRequest: Encodable {
            let text: String
            let language: String
        }

        request.httpBody = try JSONEncoder().encode(AudioRequest(text: text, language: language))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Audio generation failed")
            }
            throw APIError.serverError("Audio generation failed")
        }

        return data
    }

    // MARK: - Chat

    struct ChatHistoryMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Encodable {
        let text: String
        let context: String?
        let sourceLanguage: String?
        let messages: [ChatHistoryMessage]
    }

    func streamChat(
        selectedText: String,
        context: String? = nil,
        sourceLanguage: String? = nil,
        history: [ChatHistoryMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                text: selectedText,
                context: context,
                sourceLanguage: sourceLanguage,
                messages: history
            )
        )

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError("Chat stream failed")
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = [UInt8]()
                    for try await byte in bytes {
                        buffer.append(byte)
                        if let text = String(bytes: buffer, encoding: .utf8), !text.isEmpty {
                            continuation.yield(text)
                            buffer.removeAll()
                        }
                    }
                    if !buffer.isEmpty, let remaining = String(bytes: buffer, encoding: .utf8) {
                        continuation.yield(remaining)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    nonisolated func loadSampleImage() -> Data? {
        guard let url = Bundle.main.url(forResource: "sample-page", withExtension: "jpg") else { return nil }
        return try? Data(contentsOf: url)
    }
}

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append(value.data(using: .utf8)!)
        append("\r\n".data(using: .utf8)!)
    }
}
