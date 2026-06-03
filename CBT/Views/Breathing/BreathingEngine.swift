import Foundation
import Combine
import AVFoundation
import OSLog

enum BreathingPhase {
    case inhale
    case hold1
    case exhale
    case hold2
}

struct BreathingState {
    var phase: BreathingPhase
    var phaseSecondsRemaining: Double
    var totalSecondsRemaining: Int
    var isRunning: Bool
    var isComplete: Bool
}

@MainActor
final class BreathingEngine: ObservableObject {
    private static let logger = AppLogger.make(category: "BreathingEngine")

    @Published private(set) var state: BreathingState
    @Published public var currentAmbientSound: String = "None"

    private var pattern: BreathingPattern
    private var configuredDurationSeconds: Int
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?

    init(durationSeconds: Int = 60, pattern: BreathingPattern = .box) {
        let safeDuration = max(1, durationSeconds)
        self.configuredDurationSeconds = safeDuration
        self.pattern = pattern
        self.state = BreathingState(
            phase: .inhale,
            phaseSecondsRemaining: pattern.inhaleDuration,
            totalSecondsRemaining: safeDuration,
            isRunning: false,
            isComplete: false
        )
    }

    deinit {
        timer?.invalidate()
        audioPlayer?.stop()
    }

    func start() {
        guard !state.isRunning, !state.isComplete, state.totalSecondsRemaining > 0 else {
            return
        }
        state.isRunning = true
        startTimer()
        audioPlayer?.play()
    }

    func pause() {
        guard state.isRunning else { return }
        timer?.invalidate()
        timer = nil
        state.isRunning = false
        audioPlayer?.pause()
    }

    func stop(resetDurationSeconds: Int? = nil) {
        timer?.invalidate()
        timer = nil

        if let resetDurationSeconds {
            configuredDurationSeconds = max(1, resetDurationSeconds)
        }

        resetState(totalSeconds: configuredDurationSeconds)
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
    }

    func setDuration(seconds: Int) {
        guard !state.isRunning else { return }
        configuredDurationSeconds = max(1, seconds)
        resetState(totalSeconds: configuredDurationSeconds)
    }

    func setPattern(_ pattern: BreathingPattern) {
        guard !state.isRunning else { return }
        self.pattern = pattern
        resetState(totalSeconds: configuredDurationSeconds)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private var tickCount = 0
    private func tick() {
        guard state.isRunning else { return }

        tickCount += 1
        state.phaseSecondsRemaining -= 0.1

        // Every 10 ticks = 1 second
        if tickCount >= 10 {
            state.totalSecondsRemaining -= 1
            tickCount = 0

            if state.totalSecondsRemaining <= 0 {
                completeSession()
                return
            }
        }

        if state.phaseSecondsRemaining <= 0 {
            advancePhase()
        }
    }

    private func advancePhase() {
        var next = nextPhase(after: state.phase)

        // Skip phases with 0 duration (like hold2 in 4-7-8)
        while duration(for: next) <= 0 {
            next = nextPhase(after: next)
        }

        state.phase = next
        state.phaseSecondsRemaining = duration(for: next)
    }

    private func duration(for phase: BreathingPhase) -> Double {
        switch phase {
        case .inhale: return pattern.inhaleDuration
        case .hold1: return pattern.hold1Duration
        case .exhale: return pattern.exhaleDuration
        case .hold2: return pattern.hold2Duration
        }
    }

    private func completeSession() {
        timer?.invalidate()
        timer = nil
        state.totalSecondsRemaining = 0
        state.phaseSecondsRemaining = 0
        state.isRunning = false
        state.isComplete = true
        audioPlayer?.stop()
    }

    private func resetState(totalSeconds: Int) {
        state.phase = .inhale
        state.phaseSecondsRemaining = pattern.inhaleDuration
        state.totalSecondsRemaining = totalSeconds
        state.isRunning = false
        state.isComplete = false
        tickCount = 0
    }

    private func nextPhase(after phase: BreathingPhase) -> BreathingPhase {
        switch phase {
        case .inhale: return .hold1
        case .hold1: return .exhale
        case .exhale: return .hold2
        case .hold2: return .inhale
        }
    }

    /// INSTRUCTIONS FOR FINALIZING AMBIENT AUDIO ASSETS:
    ///
    /// To ensure these ambient sounds play correctly in the app, you must add the physical audio files to the Xcode project:
    ///
    /// 1. File Names & Casing (Must match exactly, case-sensitive):
    ///    - "Gentle Rain.mp3"
    ///    - "Ocean Waves.mp3"
    ///
    /// 2. Location inside the Project Folder:
    ///    - Move or drop the files into the `CBT/Resources/` directory in the filesystem:
    ///      `/Users/melichan/dev/CBT/CBT/Resources/`
    ///
    /// 3. Xcode Folder Mapping & Configuration:
    ///    - Open the `CBT.xcodeproj` in Xcode.
    ///    - Drag the files from Finder into the Xcode Project Navigator, dropping them under the `CBT/Resources` group/folder.
    ///    - In the dialog box that appears:
    ///      - Check "Copy items if needed".
    ///      - Select "Create groups" (not folder references).
    ///      - Under "Add to targets", ensure that the `CBT` application target is checked.
    ///    - Verify Target Membership:
    ///      - Click on "Gentle Rain.mp3" or "Ocean Waves.mp3" in Xcode's File Inspector (right sidebar).
    ///      - Confirm that the box next to `CBT` is checked in the "Target Membership" section.
    ///
    /// 4. Graceful Degradation:
    ///    - If these assets are not present or fail to load, `toggleAmbientSound` will safely degrade.
    ///    - It will set the ambient sound back to "None" and continue running the breathing session without sound or interruption.
    func toggleAmbientSound(named soundName: String, isOn: Bool) {
        if !isOn || soundName == "None" {
            audioPlayer?.stop()
            audioPlayer = nil
            currentAmbientSound = "None"
            return
        }

        // Stop any currently playing audio player to start fresh
        audioPlayer?.stop()
        audioPlayer = nil

        // Graceful Degradation Check: Verify if the audio file exists in the bundle
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            // Log warning and degrade gracefully by reverting sound to None without failing
            Self.logger.warning("Ambient sound file not found: \(soundName, privacy: .public).mp3")
            currentAmbientSound = "None"
            return
        }

        do {
            #if os(iOS)
            // Configure audio session for playback that mixes with other active audios
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            // Attempt to initialize and configure AVAudioPlayer
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // Loop indefinitely
            player.prepareToPlay()

            self.audioPlayer = player
            self.currentAmbientSound = soundName

            // Play immediately if session is already running
            if state.isRunning {
                player.play()
            }
        } catch {
            // Catch all audio initialization errors gracefully and fallback
            Self.logger.warning("Failed to initialize ambient audio player for \(soundName, privacy: .public): \(error.localizedDescription, privacy: .private)")
            self.audioPlayer = nil
            self.currentAmbientSound = "None"
        }
    }
}
