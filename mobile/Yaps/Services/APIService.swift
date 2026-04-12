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

        await attachAuthHeader(to: &request)

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

        await attachAuthHeader(to: &request)

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

        await attachAuthHeader(to: &request)

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

        await attachAuthHeader(to: &request)

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

    func fetchOCRHistory() async throws -> [OCRHistoryItem] {
        let url = URL(string: "\(baseURL)/api/history/ocr")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        await attachAuthHeader(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError("Failed to fetch history")
        }

        let decoded = try JSONDecoder.supabase.decode(OCRHistoryResponse.self, from: data)
        return decoded.data ?? []
    }

    func deleteOCRHistory(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/history/ocr/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        await attachAuthHeader(to: &request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(err.error ?? "Delete failed")
            }
            throw APIError.serverError("Delete failed")
        }
    }

    nonisolated func loadSampleImage() -> Data? {
        guard let url = Bundle.main.url(forResource: "sample-page", withExtension: "jpg") else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Auth

    private func attachAuthHeader(to request: inout URLRequest) async {
        let token = await MainActor.run { AuthService.shared.accessToken }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let decoder = JSONDecoder()
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFrac = ISO8601DateFormatter()
        withoutFrac.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFrac.date(from: string) { return date }
            if let date = withoutFrac.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(string)"
            )
        }
        return decoder
    }()
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
