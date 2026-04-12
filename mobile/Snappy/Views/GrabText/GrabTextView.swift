import SwiftUI
import UIKit

struct GrabTextView: View {
    @State private var showCamera = false
    @State private var viewModel: OCRViewModel?
    @State private var navigateToPreviewer = false
    @State private var isIntroComplete = false
    @State private var iconPulse = false

    private let languageHint = "pl"

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ZStack {
            if isIntroComplete {
                mainContent
                    .transition(.opacity)
            } else {
                introContent
                    .transition(.opacity)
            }
        }
        .navigationTitle(isIntroComplete ? "Snappy" : "")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                processImage(image)
            }
        }
        .navigationDestination(isPresented: $navigateToPreviewer) {
            if let vm = viewModel {
                PreviewerView(viewModel: vm)
            }
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.8).delay(1.2)) {
                isIntroComplete = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(2.0)) {
                iconPulse = true
            }
        }
    }

    private var introContent: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "text.viewfinder")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)

            Text("Snappy")
                .font(.system(size: 42, weight: .bold))

            Text("Вивчай польську легко")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()

            Button {
                AppTheme.hapticTap()
                scanAction()
            } label: {
                VStack(spacing: 20) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.tint)
                        .scaleEffect(iconPulse ? 1.08 : 1.0)

                    Text("Клікніть щоб сканувати")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            actionButtons
                .padding(.bottom, 32)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isCameraAvailable {
                Button {
                    AppTheme.hapticTap()
                    showCamera = true
                } label: {
                    Label("Сканувати", systemImage: "camera.fill")
                        .font(AppTheme.headlineFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
            }

            #if targetEnvironment(simulator)
            Button {
                AppTheme.hapticTap()
                useSampleText()
            } label: {
                Label(
                    isCameraAvailable ? "Використати зразок" : "Спробувати зразок",
                    systemImage: "doc.text.image.fill"
                )
                .font(AppTheme.headlineFont)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            #endif
        }
        .padding(.horizontal, 32)
    }

    private func scanAction() {
        if isCameraAvailable {
            showCamera = true
        } else {
            #if targetEnvironment(simulator)
            useSampleText()
            #endif
        }
    }

    private func useSampleText() {
        let sampleData = APIService.shared.loadSampleImage()
        processImage(sampleData)
    }

    private func processImage(_ imageData: Data?) {
        guard let data = imageData else { return }
        let vm = OCRViewModel()
        vm.startOCR(imageData: data, languageHint: languageHint)
        viewModel = vm
        navigateToPreviewer = true
    }
}
