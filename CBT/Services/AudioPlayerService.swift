import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerService()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentFileName: String?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var progressTimer: AnyCancellable?
    private var completionHandler: ((String) -> Void)?

    private override init() {
        super.init()
    }

    @discardableResult
    func playMP3(named fileName: String) -> Bool {
        playLocalAsset(named: fileName)
    }

    @discardableResult
    func playLocalAsset(
        named fileName: String,
        loop: Bool = false,
        onCompletion: ((String) -> Void)? = nil
    ) -> Bool {
        let resource = Self.resourceComponents(from: fileName)

        if currentFileName == resource.name, player != nil {
            completionHandler = onCompletion
            return resume()
        }

        guard !resource.name.isEmpty else {
            stop(clearError: false)
            errorMessage = "Audio is unavailable in this version of the app."
            return false
        }

        guard let url = Bundle.main.url(forResource: resource.name, withExtension: resource.extension) else {
            stop(clearError: false)
            errorMessage = "Audio is unavailable in this version of the app."
            return false
        }

        do {
            stop(clearError: false)
            completionHandler = onCompletion

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.numberOfLoops = loop ? -1 : 0
            player?.prepareToPlay()
            player?.play()
            currentFileName = resource.name
            duration = player?.duration ?? 0
            currentTime = player?.currentTime ?? 0
            isPlaying = true
            errorMessage = nil
            startProgressTimer()
            return true
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
            stopProgressTimer()
            return false
        }
    }

    @discardableResult
    func resume() -> Bool {
        guard let player else { return false }
        player.play()
        isPlaying = true
        errorMessage = nil
        startProgressTimer()
        return true
    }

    func pause() {
        player?.pause()
        syncProgress()
        isPlaying = false
        stopProgressTimer()
    }

    func stop() {
        stop(clearError: true)
    }

    func seek(by seconds: TimeInterval) {
        guard let player else { return }
        seek(to: player.currentTime + seconds)
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let target = min(max(0, time), max(player.duration, 0))
        player.currentTime = target
        syncProgress()

        if player.duration > 0, target >= player.duration {
            completePlayback(player, successfully: true)
        }
    }

    func isLoadedAsset(named fileName: String) -> Bool {
        currentFileName == Self.resourceComponents(from: fileName).name && player != nil
    }

    func localAssetExists(named fileName: String) -> Bool {
        let resource = Self.resourceComponents(from: fileName)
        guard !resource.name.isEmpty else { return false }
        return Bundle.main.url(forResource: resource.name, withExtension: resource.extension) != nil
    }

    private func stop(clearError: Bool) {
        player?.stop()
        player?.delegate = nil
        player = nil
        currentFileName = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        completionHandler = nil
        stopProgressTimer()
        if clearError {
            errorMessage = nil
        }
    }

    func isPlayingAsset(named fileName: String) -> Bool {
        isPlaying && currentFileName == Self.resourceComponents(from: fileName).name
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.completePlayback(player, successfully: flag)
        }
    }

    private func completePlayback(_ completedPlayer: AVAudioPlayer, successfully flag: Bool) {
        guard player === completedPlayer else { return }

        syncProgress()
        let completedFileName = currentFileName
        currentTime = duration
        completedPlayer.delegate = nil
        player = nil
        currentFileName = nil
        isPlaying = false
        stopProgressTimer()

        if flag, let completedFileName {
            let handler = completionHandler
            completionHandler = nil
            handler?(completedFileName)
        } else {
            completionHandler = nil
        }
    }

    private func syncProgress() {
        guard let player else { return }
        currentTime = player.currentTime
        duration = player.duration
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncProgress()
                }
            }
    }

    private func stopProgressTimer() {
        progressTimer?.cancel()
        progressTimer = nil
    }

    private static func resourceComponents(from fileName: String) -> (name: String, extension: String) {
        let url = URL(fileURLWithPath: fileName)
        let fileExtension = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
        let name = url.deletingPathExtension().lastPathComponent
        return (name, fileExtension)
    }
}
