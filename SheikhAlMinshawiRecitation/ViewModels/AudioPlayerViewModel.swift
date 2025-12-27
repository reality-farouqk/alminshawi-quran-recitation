//
//  ViewModels/AudioPlayerViewModel.swift
//  Sheikh Al Minshawi Recitation - offline
//
//  Created by UmarFarouqk on 12/12/2025.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

struct AudioConfig {

    static let baseURL = "https://quran-audio-api.farouqkdesigns.com"

    static func signURL(_ number: Int) -> URL {
        return URL(string: "\(baseURL)/sign?surah=\(number)")!
    }
}

final class AudioCache {
    static let shared = AudioCache()

    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func localURL(for surah: Int) -> URL {
        let file = String(format: "%03d.m4a", surah)
        return directory.appendingPathComponent(file)
    }

    func exists(_ surah: Int) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: surah).path)
    }
}

enum DownloadFailure: LocalizedError {
    case noInternet
    case serverUnavailable
    case fileNotFound
    case diskError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No internet connection. Please connect and try again."
        case .serverUnavailable:
            return "Audio server is unavailable. Try again later."
        case .fileNotFound:
            return "Audio file not found on server."
        case .diskError:
            return "Unable to save audio to device storage."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

final class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate, URLSessionDownloadDelegate {

    // MARK: - Published UI State
    @Published var isPlaying: Bool = false
    @Published var currentSurah: Surah?
    @Published var queue: [Surah] = []
    @Published var shuffle: Bool = false
    enum RepeatMode: Int { case off = 0, one = 1, all = 2 }
    @Published var repeatMode: RepeatMode = .off
    private var currentIndex: Int? = nil

    @Published var errorMessage: String?
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var downloadedSurahs: Set<Int> = []
    @Published var downloadError: DownloadFailure?
    @Published var downloadStatus: String?
    @Published var currentDownloadingSurah: Surah?

    // MARK: - Private
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var downloadSession: URLSession?
    private var currentDownloadSurah: Surah?
    private var currentDownloadCompletion: ((URL?) -> Void)?
    private var currentLocalURL: URL?
    private var pendingPlaybackRequestId: UUID? // Track the most recent playback request
    private let downloadedKey = "downloadedSurahs"

    override init() {
        super.init()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            self.errorMessage = "Audio session error: \(error.localizedDescription)"
        }

        setupRemoteCommands()

        // Load persisted downloaded surahs
        if let saved = UserDefaults.standard.array(forKey: downloadedKey) as? [Int] {
            downloadedSurahs = Set(saved)
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)

        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)

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

        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.nextSurah()
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.previousSurah()
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let evt = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: evt.positionTime)
            return .success
        }
    }

    // MARK: - Public Controls

    private func getSignedURL(for surah: Int, completion: @escaping (URL?) -> Void) {
        let signURL = AudioConfig.signURL(surah)
        var request = URLRequest(url: signURL)
        request.setValue("SheikhMinshawiIOS", forHTTPHeaderField: "X-App-Token")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let signedURLString = json["url"],
                  let signedURL = URL(string: signedURLString) else {
                completion(nil)
                return
            }
            completion(signedURL)
        }.resume()
    }

    func prepareAudio(for surah: Surah, requestId: UUID? = nil, completion: @escaping (URL, UUID?) -> Void) {
        let cache = AudioCache.shared

        if cache.exists(surah.number) {
            completion(cache.localURL(for: surah.number), requestId)
            return
        }

        // Download with progress
        currentDownloadSurah = surah
        currentLocalURL = cache.localURL(for: surah.number)
        currentDownloadingSurah = surah
        downloadProgress = 0
        isDownloading = true
        downloadError = nil
        downloadStatus = nil

        // First get signed URL, then download
        getSignedURL(for: surah.number) { [weak self] signedURL in
            guard let self = self, let signedURL = signedURL else {
                DispatchQueue.main.async {
                    self?.downloadError = .serverUnavailable
                    self?.isDownloading = false
                }
                return
            }

            DispatchQueue.main.async {
                print("Starting download for Surah \(surah.number) from signed URL: \(signedURL) (request: \(requestId?.uuidString ?? "none"))")

                var request = URLRequest(url: signedURL)
                request.setValue("SheikhMinshawiIOS", forHTTPHeaderField: "X-App-Token")

                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 60  // Increased timeout
                config.timeoutIntervalForResource = 300  // Overall timeout
                config.waitsForConnectivity = true
                config.requestCachePolicy = .reloadIgnoringLocalCacheData

                self.downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                let task = self.downloadSession!.downloadTask(with: request)
                task.resume()

                // Store completion with request ID for later use
                self.currentDownloadCompletion = { url in
                    completion(url ?? cache.localURL(for: surah.number), requestId)
                }
            }
        }
    }

    func playSurah(_ surah: Surah) {
        // Generate new request ID to track this playback request
        let requestId = UUID()
        pendingPlaybackRequestId = requestId

        let cache = AudioCache.shared

        if cache.exists(surah.number) {
            // Play from cache
            currentSurah = surah
            if let idx = queue.firstIndex(where: { $0.id == surah.id }) { currentIndex = idx }
            handlePlayerURL(cache.localURL(for: surah.number))
            return
        }

        // Check bundle
        let filename = String(format: "%03d", surah.number)
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: "m4a", subdirectory: "Audio") {
            currentSurah = surah
            if let idx = queue.firstIndex(where: { $0.id == surah.id }) { currentIndex = idx }
            handlePlayerURL(bundleURL)
            return
        }

        // Download and play - store request ID for later validation
        prepareAudio(for: surah, requestId: requestId) { [weak self] fileURL, completedRequestId in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Only play if this is still the most recent request
                guard self.pendingPlaybackRequestId == completedRequestId else {
                    print("Skipping playback - newer request pending")
                    return
                }

                self.currentSurah = surah
                if let idx = self.queue.firstIndex(where: { $0.id == surah.id }) { self.currentIndex = idx }
                self.handlePlayerURL(fileURL)
            }
        }
    }

    func retryDownload(for surah: Surah) {
        downloadError = nil
        playSurah(surah)
    }

    // MARK: - URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            if totalBytesExpectedToWrite > 0 {
                self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard
            let surah = currentDownloadSurah,
            let localURL = currentLocalURL
        else { return }

        do {
            let fm = FileManager.default

            // Ensure destination directory exists
            try fm.createDirectory(
                at: localURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Remove existing file
            if fm.fileExists(atPath: localURL.path) {
                try fm.removeItem(at: localURL)
            }

            // 🔥 MOVE IMMEDIATELY (NOT async)
            try fm.moveItem(at: location, to: localURL)

            // Validate audio
            let player = try AVAudioPlayer(contentsOf: localURL)
            guard player.duration > 0 else {
                throw DownloadFailure.fileNotFound
            }

            DispatchQueue.main.async {
                self.downloadedSurahs.insert(surah.number)
                self.persistDownloadedSurahs()
                self.downloadStatus = "Download completed"
                self.isDownloading = false
                self.currentDownloadingSurah = nil

                // ✅ THIS IS THE ONLY PLACE PLAYBACK CONTINUES
                self.currentDownloadCompletion?(localURL)

                self.currentDownloadCompletion = nil
                self.currentDownloadSurah = nil
                self.currentLocalURL = nil
            }

        } catch {
            DispatchQueue.main.async {
                self.downloadError = .diskError
                self.isDownloading = false
            }
        }

        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("Download failed with error: \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    print("URLError code: \(urlError.code.rawValue)")
                    switch urlError.code {
                    case .notConnectedToInternet:
                        self.downloadError = .noInternet
                    case .timedOut, .networkConnectionLost, .cannotConnectToHost:
                        self.downloadError = .serverUnavailable
                    case .fileDoesNotExist, .badServerResponse:
                        self.downloadError = .fileNotFound
                    default:
                        self.downloadError = .unknown(urlError)
                    }
                } else {
                    self.downloadError = .unknown(error)
                }
                self.currentDownloadCompletion?(nil)
            } else {
                print("Download task completed successfully")
            }

            // Cleanup
            self.isDownloading = false
            self.downloadProgress = 0
            self.currentDownloadSurah = nil
            self.currentDownloadCompletion = nil
            self.currentLocalURL = nil
            self.currentDownloadingSurah = nil
            self.downloadSession?.invalidateAndCancel()
            self.downloadSession = nil
        }
    }

    private func handlePlayerURL(_ url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
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
        }
    }

    // MARK: - AVAudioPlayerDelegate
    @objc func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        // When a track finishes, handle repeat-one (replay) or advance to next
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.repeatMode == .one {
                // replay current track
                if let cur = self.currentIndex {
                    self.playSurah(self.queue[cur])
                } else if let surah = self.currentSurah {
                    self.playSurah(surah)
                }
            } else {
                self.nextSurah()
            }
        }
    }

    // MARK: - Queue Navigation
    func setQueue(_ surahs: [Surah]) {
        queue = surahs
        if let cur = currentSurah, let idx = queue.firstIndex(where: { $0.id == cur.id }) {
            currentIndex = idx
        } else {
            currentIndex = nil
        }
    }

    func nextSurah() {
        guard !queue.isEmpty else { return }
        // When shuffle is enabled we already randomize the queue in toggleShuffle(),
        // so here advance sequentially through the (possibly shuffled) queue.
        if let cur = currentIndex {
            let next = cur + 1
            if next < queue.count {
                currentIndex = next
            } else {
                if repeatMode == .all {
                    currentIndex = 0
                } else if repeatMode == .one {
                    // repeat one handled in delegate; here, if user pressed next at end and repeat one,
                    // advance to start (or keep same). We'll keep behavior: if repeat one, replay current.
                    currentIndex = cur
                } else {
                    pause()
                    return
                }
            }
        } else {
            currentIndex = 0
        }

        if let idx = currentIndex {
            playSurah(queue[idx])
        }
    }

    func previousSurah() {
        guard !queue.isEmpty else { return }
        if shuffle {
            currentIndex = Int.random(in: 0..<queue.count)
        } else if let cur = currentIndex {
            let prev = cur - 1
            if prev >= 0 {
                currentIndex = prev
            } else {
                if repeatMode == .all {
                    currentIndex = queue.count - 1
                } else if repeatMode == .one {
                    currentIndex = cur
                } else {
                    pause()
                    return
                }
            }
        } else {
            currentIndex = queue.count - 1
        }

        if let idx = currentIndex {
            playSurah(queue[idx])
        }
    }

    func toggleShuffle() {
        shuffle.toggle()
        guard !queue.isEmpty else { return }
        if shuffle {
            queue.shuffle()
        } else {
            queue.sort { $0.id < $1.id }
        }
        if let cur = currentSurah, let idx = queue.firstIndex(where: { $0.id == cur.id }) {
            currentIndex = idx
        } else {
            currentIndex = nil
        }
    }

    func cycleRepeatMode() {
        let nextRaw = (repeatMode.rawValue + 1) % 3
        repeatMode = RepeatMode(rawValue: nextRaw) ?? .off
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
            // keep Now Playing elapsed time in sync
            self.updateNowPlaying()
        }
    }

    private func stopProgressTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func persistDownloadedSurahs() {
        UserDefaults.standard.set(Array(downloadedSurahs), forKey: downloadedKey)
    }
}
