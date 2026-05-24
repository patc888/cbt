import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentFileName: String?
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?

    private init() {}

    func playMP3(named fileName: String) {
        let resourceName = fileName.replacingOccurrences(of: ".mp3", with: "")
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3") else {
            errorMessage = "Audio file not found."
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            currentFileName = resourceName
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
        player = nil
        currentFileName = nil
        isPlaying = false
    }
}
