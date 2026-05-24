import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerService()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentFileName: String?
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?

    private override init() {
        super.init()
    }

    func playMP3(named fileName: String) {
        playLocalAsset(named: fileName)
    }

    func playLocalAsset(named fileName: String, loop: Bool = false) {
        let resource = Self.resourceComponents(from: fileName)
        guard let url = Bundle.main.url(forResource: resource.name, withExtension: resource.extension) else {
            errorMessage = "Audio file not found."
            return
        }

        do {
            stop()

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.numberOfLoops = loop ? -1 : 0
            player?.prepareToPlay()
            player?.play()
            currentFileName = resource.name
            isPlaying = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        player?.delegate = nil
        player = nil
        currentFileName = nil
        isPlaying = false
    }

    func isPlayingAsset(named fileName: String) -> Bool {
        isPlaying && currentFileName == Self.resourceComponents(from: fileName).name
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.player = nil
            self?.currentFileName = nil
            self?.isPlaying = false
        }
    }

    private static func resourceComponents(from fileName: String) -> (name: String, extension: String) {
        let url = URL(fileURLWithPath: fileName)
        let fileExtension = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
        let name = url.deletingPathExtension().lastPathComponent
        return (name, fileExtension)
    }
}
