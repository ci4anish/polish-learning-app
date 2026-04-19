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

    private struct ErrorResponse: Decodable { let error: String? }

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

    // MARK: - Chat

    private struct ChatStartRequest: Encodable {
        let text: String
        let context: String?
        let sourceLanguage: String?
    }

    private struct ChatStartResponse: Decodable {
        let success: Bool
        let threadId: String?
        let error: String?
    }

    private struct ChatMessageRequest: Encodable {
        let threadId: String
        let message: String
    }

    func chatStart(text: String, context: String? = nil, sourceLanguage: String? = nil) async throws -> String {
        let url = URL(string: "\(baseURL)/api/chat/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await attachAuthHeader(to: &request)

        request.httpBody = try JSONEncoder().encode(
            ChatStartRequest(text: text, context: context, sourceLanguage: sourceLanguage)
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

        let decoded = try JSONDecoder().decode(ChatStartResponse.self, from: data)

        guard decoded.success, let threadId = decoded.threadId else {
            throw APIError.serverError(decoded.error ?? "Failed to start chat (HTTP \(http.statusCode))")
        }

        return threadId
    }

    func streamChatMessage(threadId: String, message: String) async throws -> AsyncThrowingStream<String, Error> {
        let url = URL(string: "\(baseURL)/api/chat/message")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await attachAuthHeader(to: &request)

        request.httpBody = try JSONEncoder().encode(
            ChatMessageRequest(threadId: threadId, message: message)
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
