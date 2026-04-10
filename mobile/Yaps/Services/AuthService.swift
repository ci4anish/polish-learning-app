import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    let supabase = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabasePublishableKey
    )

    var session: Session?
    var isLoading = false
    var errorMessage: String?

    var isAuthenticated: Bool { session != nil }
    var accessToken: String? { session?.accessToken }

    private init() {
        Task { await startAuthStateListener() }
    }

    private func startAuthStateListener() async {
        for await (event, session) in await supabase.auth.authStateChanges {
            print("[Auth] state change: \(event), session: \(session != nil)")
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                self.session = session
            default:
                self.session = nil
            }
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "com.yaps.app://auth/callback")
            )
        } catch {
            print("[Auth] signInWithGoogle error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func handleDeepLink(_ url: URL) async {
        print("[Auth] handleDeepLink: \(url)")
        do {
            try await supabase.auth.session(from: url)
        } catch {
            print("[Auth] handleDeepLink error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
