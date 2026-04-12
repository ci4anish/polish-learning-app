import MarkdownUI
import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle("AI Репетитор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.cancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { viewModel.startChat() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty && viewModel.isStreaming {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.1)
                            Text("Починаю розмову…")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }

                    if let error = viewModel.error, viewModel.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.secondary)
                            Text(error)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .padding(.horizontal, 32)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, isStreaming: isLastAssistant(message) && viewModel.isStreaming)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, YapsTheme.padding)
                .padding(.top, YapsTheme.padding)
                .padding(.bottom, YapsTheme.largePadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private func isLastAssistant(_ message: ChatMessage) -> Bool {
        guard let last = viewModel.messages.last else { return false }
        return last.id == message.id && message.role == .assistant
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Запитайте щось…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: .capsule)
                .focused($isInputFocused)

            Button {
                YapsTheme.hapticTap()
                viewModel.sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
            .opacity(viewModel.isStreaming ? 0.4 : 1.0)
        }
        .padding(.horizontal, YapsTheme.padding)
        .padding(.vertical, YapsTheme.smallPadding)
        .background(.bar)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isStreaming: Bool

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    contentView
                } else {
                    Text(message.content)
                        .font(.system(.body, design: .rounded))
                }

                if isStreaming && message.content.isEmpty {
                    TypingIndicator()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground, in: .rect(cornerRadius: YapsTheme.cornerRadius))

            if message.role == .assistant { Spacer(minLength: 8) }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        Markdown(message.content)
            .markdownTheme(.yaps)
    }

    private var bubbleBackground: some ShapeStyle {
        message.role == .user
            ? AnyShapeStyle(.tint.opacity(0.15))
            : AnyShapeStyle(.ultraThinMaterial)
    }
}

private struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotScale(for: index))
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear { phase = 1.0 }
    }

    private func dotScale(for index: Int) -> CGFloat {
        phase == 0.0 ? 0.5 : 1.0
    }
}

extension MarkdownUI.Theme {
    @MainActor static let yaps = Theme()
        .text {
            FontFamily(.system(.rounded))
            FontSize(17)
        }
        .heading1 { configuration in
            configuration.label
                .font(.system(.title3, design: .rounded, weight: .bold))
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading2 { configuration in
            configuration.label
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .markdownMargin(top: 6, bottom: 2)
        }
        .codeBlock { configuration in
            configuration.label
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .background(.quaternary, in: .rect(cornerRadius: 8))
                .markdownMargin(top: 4, bottom: 4)
        }
}
