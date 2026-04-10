import SwiftUI

enum MagicButtonState {
    case idle
    case thinking
    case done
}

struct MagicButton: View {
    let state: MagicButtonState
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -100

    var body: some View {
        Button(action: {
            if state == .idle {
                YapsTheme.hapticTap()
                action()
            }
        }) {
            HStack(spacing: 6) {
                icon
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 26, height: 26)

                if state == .thinking {
                    Text("Думаю…")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, state == .thinking ? 20 : 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .capsule)
            .scaleEffect(state == .thinking ? pulseScale : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(state == .thinking)
        .onChange(of: state) { _, newState in
            if newState == .thinking {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            } else {
                withAnimation(.spring(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(duration: 0.4, bounce: 0.3), value: state)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .idle:
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .speed(0.5))
        case .thinking:
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.7))
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
        }
    }
}
