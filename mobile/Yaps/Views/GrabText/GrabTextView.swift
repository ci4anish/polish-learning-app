import SwiftUI
import UIKit

struct GrabTextView: View {
    @State private var showCamera = false
    @State private var ocrResult: OCRResult?
    @State private var isProcessing = false
    @State private var navigateToPreviewer = false
    @State private var heroScale: CGFloat = 0.8
    @State private var heroOpacity: CGFloat = 0

    private let languageHint = "pl"

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
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.4)) {
                heroScale = 1.0
                heroOpacity = 1.0
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 130, height: 130)
                .overlay(
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.tint)
                )

            Text("Сканувати текст")
                .font(YapsTheme.titleFont)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isCameraAvailable {
                Button {
                    YapsTheme.hapticTap()
                    showCamera = true
                } label: {
                    Label("Сканувати", systemImage: "camera.fill")
                        .font(YapsTheme.headlineFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
            }

            #if targetEnvironment(simulator)
            Button {
                YapsTheme.hapticTap()
                useSampleText()
            } label: {
                Label(
                    isCameraAvailable ? "Використати зразок" : "Спробувати зразок",
                    systemImage: "doc.text.image.fill"
                )
                .font(YapsTheme.headlineFont)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            #endif
        }
        .padding(.horizontal, 32)
    }

    private func useSampleText() {
        let sampleData = APIService.shared.loadSampleImage()
        processImage(sampleData)
    }

    private func processImage(_ imageData: Data?) {
        guard let data = imageData else { return }
        isProcessing = true
        Task {
            do {
                let result = try await APIService.shared.performOCR(
                    imageData: data,
                    languageHint: languageHint
                )
                ocrResult = result
                isProcessing = false
                navigateToPreviewer = true
            } catch {
                print("[GrabText] OCR failed:", error.localizedDescription)
                isProcessing = false
            }
        }
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

                Text("Аналізую текст…")
                    .font(YapsTheme.headlineFont)
            }
            .padding(32)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }
}
