import SwiftUI
import UIKit

struct GrabTextView: View {
    @State private var showCamera = false
    @State private var ocrResult: OCRResult?
    @State private var isProcessing = false
    @State private var navigateToPreviewer = false
    @State private var scanCount = 0
    @State private var heroScale: CGFloat = 0.8
    @State private var heroOpacity: CGFloat = 0
    @State private var selectedLanguage: ContentLanguage?
    @State private var showLanguagePicker = false

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            heroSection
                .scaleEffect(heroScale)
                .opacity(heroOpacity)

            Spacer()

            actionButtons
                .padding(.bottom, 32)
        }
        .navigationTitle("Yaps")
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                processImage(image)
            }
        }
        .navigationDestination(isPresented: $navigateToPreviewer) {
            if let result = ocrResult {
                PreviewerView(ocrResult: result)
            }
        }
        .overlay {
            if isProcessing {
                ProcessingOverlay()
            }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguageSelectorSheet { language in
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    selectedLanguage = language
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.4)) {
                heroScale = 1.0
                heroOpacity = 1.0
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 20) {
            languageBadge

            VStack(spacing: 8) {
                Text("Grab Text")
                    .font(YapsTheme.titleFont)

                if let lang = selectedLanguage {
                    HStack(spacing: 6) {
                        Text("Content in **\(lang.name)**")
                            .font(YapsTheme.bodyFont)
                            .foregroundStyle(.secondary)

                        Button {
                            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                                selectedLanguage = nil
                            }
                            YapsTheme.hapticTap()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.blurReplace)
                } else {
                    Text("Tap the icon to set content language")
                        .font(YapsTheme.bodyFont)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .transition(.blurReplace)
                }
            }

            if scanCount > 0 {
                Label("\(scanCount) text\(scanCount == 1 ? "" : "s") scanned", systemImage: "checkmark.circle.fill")
                    .font(YapsTheme.captionFont)
                    .foregroundStyle(.secondary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var languageBadge: some View {
        Button {
            YapsTheme.hapticTap()
            showLanguagePicker = true
        } label: {
            ZStack {
                if let lang = selectedLanguage {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: lang.flagColors.map { $0.opacity(0.25) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 130, height: 130)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: lang.flagColors.map { $0.opacity(0.5) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.5
                                )
                        )
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 130, height: 130)
                        .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 6) {
                    Image(systemName: selectedLanguage != nil ? "character.book.closed.fill" : "text.viewfinder")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.tint)
                        .contentTransition(.symbolEffect(.replace))

                    if let lang = selectedLanguage {
                        Text(lang.id.uppercased())
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.tint)
                            .transition(.blurReplace)
                    }
                }
            }
        }
        .buttonStyle(LanguageBadgeButtonStyle())
        .animation(.spring(duration: 0.5, bounce: 0.3), value: selectedLanguage)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isCameraAvailable {
                Button {
                    YapsTheme.hapticTap()
                    showCamera = true
                } label: {
                    Label("Scan Text", systemImage: "camera.fill")
                        .font(YapsTheme.headlineFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
            }

            Button {
                YapsTheme.hapticTap()
                useSampleText()
            } label: {
                Label(
                    isCameraAvailable ? "Use Sample Text" : "Try Sample Text",
                    systemImage: "doc.text.fill"
                )
                .font(YapsTheme.headlineFont)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 32)
    }

    private func useSampleText() {
        processImage(nil)
    }

    private func processImage(_ imageData: Data?) {
        isProcessing = true
        Task {
            do {
                let result = try await MockAPIService.shared.performOCR(image: imageData)
                ocrResult = result
                isProcessing = false
                withAnimation { scanCount += 1 }
                navigateToPreviewer = true
            } catch {
                isProcessing = false
            }
        }
    }
}

struct LanguageBadgeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(duration: 0.3, bounce: 0.4), value: configuration.isPressed)
    }
}

struct ProcessingOverlay: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                Text("Analyzing text…")
                    .font(YapsTheme.headlineFont)
            }
            .padding(32)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }
}
