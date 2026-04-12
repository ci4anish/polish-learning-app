import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.accentColor)

                Text("Snappy")
                    .font(.system(size: 42, weight: .bold))

                Text("Вивчай польську легко")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                if auth.isLoading {
                    ProgressView()
                        .frame(height: 50)
                } else {
                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.title3)
                            Text("Увійти через Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let message = auth.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthService.shared)
}
