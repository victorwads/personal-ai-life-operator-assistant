import AVFoundation
import os
import SwiftUI

struct AudioMessageView: View {
    let audioURL: URL

    @StateObject private var playbackController = AudioMessagePlaybackController()

    var body: some View {
        Button {
            playbackController.togglePlayback(for: audioURL)
        } label: {
            Text(playbackController.isPlaying ? "⏸ Audio" : "▶ Audio")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playbackController.isPlaying ? "Pause audio" : "Play audio")
        .accessibilityHint(audioURL.lastPathComponent)
    }
}

private final class AudioMessagePlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false

    private var player: AVAudioPlayer?
    private var currentURL: URL?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AIAssistantHub",
        category: "AudioMessageView"
    )

    func togglePlayback(for url: URL) {
        if currentURL != url || player == nil {
            loadPlayer(for: url)
        }

        guard let player else {
            return
        }

        if isPlaying {
            pausePlayback()
        } else {
            startPlayback(player)
        }
    }

    private func loadPlayer(for url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            currentURL = url
        } catch {
            isPlaying = false
            self.player = nil
            currentURL = nil
            logger.error("Failed to load audio file at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startPlayback(_ player: AVAudioPlayer) {
        if player.currentTime >= player.duration {
            player.currentTime = 0
        }

        guard player.play() else {
            isPlaying = false
            logger.error("Failed to start audio playback for \(player.url?.path ?? "unknown", privacy: .public)")
            return
        }

        isPlaying = true
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            if !flag {
                self.logger.error("Audio playback ended unsuccessfully for \(player.url?.path ?? "unknown", privacy: .public)")
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
            if let error {
                self.logger.error("Audio decode error for \(player.url?.path ?? "unknown", privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                self.logger.error("Audio decode error for \(player.url?.path ?? "unknown", privacy: .public)")
            }
        }
    }
}
