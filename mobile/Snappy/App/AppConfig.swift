import Foundation

enum AppConfig {
    static let apiBaseURL: String = {
        #if targetEnvironment(simulator)
        return "http://localhost:8787"
        #else
        return string(for: "APIBaseURL")
        #endif
    }()

    private static func string(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            fatalError("Missing or empty config key '\(key)' — check Config.xcconfig")
        }
        return value
    }
}
