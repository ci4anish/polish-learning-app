import AVFoundation
import SwiftUI

struct AudioButton: View {
    let text: String

    @State private var isLoading = false
    @State private var isPlaying = false
    @State private var errorMessage: String?
    @State private var playerDelegate = AudioPlayerDelegate()

    private static var cache: [String: Data] = [:]

    var body: some View {
        Button {
            guard !isLoading else { return }
            YapsTheme.hapticTap()
            Task { await togglePlayback() }
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                }
                Text("Аудіо")
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .onChange(of: playerDelegate.isFinished) { _, finished in
            if finished { isPlaying = false }
        }
        .popover(isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Text(errorMessage ?? "")
                .font(.system(.caption, design: .rounded))
                .padding(12)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func togglePlayback() async {
        if isPlaying {
            playerDelegate.stop()
            isPlaying = false
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let audioData: Data
            if let cached = Self.cache[text] {
                audioData = cached
            } else {
                audioData = try await APIService.shared.getAudio(text: text)
                Self.cache[text] = audioData
            }
            try playerDelegate.play(data: audioData)
            isLoading = false
            isPlaying = true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var isFinished = false

    func play(data: Data) throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        isFinished = false
        player = try AVAudioPlayer(data: data)
        player?.delegate = self
        player?.volume = 1.0
        player?.prepareToPlay()
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        isFinished = true
    }
}
