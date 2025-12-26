//
//  AudioPlayerViewModel.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

final class AudioPlayerViewModel: ObservableObject {

    // MARK: - Published UI State
    @Published var isPlaying: Bool = false
    @Published var currentSurah: Surah?
    
    @Published var errorMessage: String?
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    // MARK: - Private
    private var player: AVAudioPlayer?
    private var timer: Timer?

    init() {
        DispatchQueue.main.async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                self.errorMessage = "Audio session error: \(error.localizedDescription)"
                print("Audio session setup failed: \(error)")
            }
            self.setupRemoteCommands()
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)

        center.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.play()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.pause()
            return .success
        }
    }

    // MARK: - Public Controls

    func playSurah(_ surah: Surah) {
        currentSurah = surah

        let filename = String(format: "%03d", surah.id)

        guard let url = Bundle.main.url(
            forResource: filename,
            withExtension: "mp3",
            subdirectory: "Audio"
        ) else {
            // Try without subdirectory in case files were added at bundle root
            if let fallback = Bundle.main.url(forResource: filename, withExtension: "mp3") {
                handlePlayerURL(fallback)
                return
            }

            // Print all mp3s found in bundle for debugging
            if let bundleMp3s = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
                print("MP3s in bundle: \(bundleMp3s.map { $0.lastPathComponent })")
            } else {
                print("No mp3 files found in bundle")
            }

            errorMessage = "Surah audio not found: \(filename).mp3"
            print("Failed to find audio file in bundle: \(filename).mp3")
            return
        }

        do {
            handlePlayerURL(url)
        } catch {
            errorMessage = "Playback error: \(error.localizedDescription)"
            print("AVAudioPlayer error: \(error)")
        }
    }

    private func handlePlayerURL(_ url: URL) {
        do {
            print("Playing audio at URL: \(url)")
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            progress = 0
            player?.play()
            isPlaying = true
            startProgressTimer()

            // Update Now Playing info
            updateNowPlaying()
        } catch {
            errorMessage = "Playback error: \(error.localizedDescription)"
            print("AVAudioPlayer error: \(error)")
        }
    }

    private func updateNowPlaying() {
        guard let surah = currentSurah else { return }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = surah.nameSimple
        info[MPMediaItemPropertyArtist] = surah.englishName
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = (isPlaying ? 1.0 : 0.0)

        // Optional: set artwork if available in assets
        if let image = UIImage(named: "AppIcon") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func play() {
        player?.play()
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
    }



    func seek(to value: Double) {
        player?.currentTime = value
        progress = value
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Internal Playback

    


    private func startProgressTimer() {
        stopProgressTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let player = self.player else { return }
            self.progress = player.currentTime
        }
    }

    private func stopProgressTimer() {
        timer?.invalidate()
        timer = nil
    }
}
