import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        let host = string(for: "SupabaseHost")
        guard let url = URL(string: "https://\(host)") else {
            fatalError("Invalid SupabaseHost in Config.xcconfig: \(host)")
        }
        return url
    }()

    static let supabasePublishableKey: String = string(for: "SupabasePublishableKey")

    static let apiBaseURL: String = string(for: "APIBaseURL")

    private static func string(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            fatalError("Missing or empty config key '\(key)' — check Config.xcconfig")
        }
        return value
    }
}
