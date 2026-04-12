import SwiftUI
import UIKit

struct GrabTextView: View {
    @State private var showCamera = false
    @State private var viewModel: OCRViewModel?
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
            if let vm = viewModel {
                PreviewerView(viewModel: vm)
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
        Button {
            YapsTheme.hapticTap()
            scanAction()
        } label: {
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
        .buttonStyle(.plain)
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
