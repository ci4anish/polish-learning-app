import AVFoundation
import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data?) -> Void

    func makeUIViewController(context: Context) -> CameraCaptureController {
        let controller = CameraCaptureController()
        controller.onCapture = { data in
            dismiss()
            onCapture(data)
        }
        controller.onCancel = {
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraCaptureController, context: Context) {}
}

final class CameraCaptureController: UIViewController {
    var onCapture: ((Data?) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var delegate: PhotoDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func setupCamera() {
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output) else { return }

        session.addInput(input)
        session.addOutput(output)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    private func setupUI() {
        let shutterButton = UIButton(type: .system)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)

        let outerRing = UIView()
        outerRing.translatesAutoresizingMaskIntoConstraints = false
        outerRing.isUserInteractionEnabled = false
        outerRing.layer.cornerRadius = 37
        outerRing.layer.borderWidth = 4
        outerRing.layer.borderColor = UIColor.white.cgColor

        let innerCircle = UIView()
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.isUserInteractionEnabled = false
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30

        view.addSubview(shutterButton)
        shutterButton.addSubview(outerRing)
        shutterButton.addSubview(innerCircle)

        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterButton.widthAnchor.constraint(equalToConstant: 74),
            shutterButton.heightAnchor.constraint(equalToConstant: 74),

            outerRing.centerXAnchor.constraint(equalTo: shutterButton.centerXAnchor),
            outerRing.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            outerRing.widthAnchor.constraint(equalToConstant: 74),
            outerRing.heightAnchor.constraint(equalToConstant: 74),

            innerCircle.centerXAnchor.constraint(equalTo: shutterButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60),

            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
        ])
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        delegate = PhotoDelegate { [weak self] data in
            self?.onCapture?(data)
        }
        output.capturePhoto(with: settings, delegate: delegate!)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async { [self] in
            completion(data)
        }
    }
}
