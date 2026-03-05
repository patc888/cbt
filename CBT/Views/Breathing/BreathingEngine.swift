import Foundation
import Combine

enum BreathingPhase {
    case inhale
    case hold1
    case exhale
    case hold2
}

struct BreathingState {
    var phase: BreathingPhase
    var phaseSecondsRemaining: Int
    var totalSecondsRemaining: Int
    var isRunning: Bool
    var isComplete: Bool
}

@MainActor
final class BreathingEngine: ObservableObject {
    @Published private(set) var state: BreathingState

    private let phaseLengthSeconds = 4
    private var configuredDurationSeconds: Int
    private var timer: Timer?

    init(durationSeconds: Int = 60) {
        let safeDuration = max(1, durationSeconds)
        configuredDurationSeconds = safeDuration
        state = BreathingState(
            phase: .inhale,
            phaseSecondsRemaining: phaseLengthSeconds,
            totalSecondsRemaining: safeDuration,
            isRunning: false,
            isComplete: false
        )
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard !state.isRunning, !state.isComplete, state.totalSecondsRemaining > 0 else {
            return
        }
        state.isRunning = true
        startTimer()
    }

    func pause() {
        guard state.isRunning else { return }
        timer?.invalidate()
        timer = nil
        state.isRunning = false
    }

    func stop(resetDurationSeconds: Int? = nil) {
        timer?.invalidate()
        timer = nil

        if let resetDurationSeconds {
            configuredDurationSeconds = max(1, resetDurationSeconds)
        }

        resetState(totalSeconds: configuredDurationSeconds)
    }

    func setDuration(seconds: Int) {
        guard !state.isRunning else { return }
        configuredDurationSeconds = max(1, seconds)
        resetState(totalSeconds: configuredDurationSeconds)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard state.isRunning else { return }

        state.totalSecondsRemaining -= 1
        state.phaseSecondsRemaining -= 1

        if state.totalSecondsRemaining <= 0 {
            completeSession()
            return
        }

        if state.phaseSecondsRemaining <= 0 {
            state.phase = nextPhase(after: state.phase)
            state.phaseSecondsRemaining = phaseLengthSeconds
        }
    }

    private func completeSession() {
        timer?.invalidate()
        timer = nil
        state.totalSecondsRemaining = 0
        state.phaseSecondsRemaining = 0
        state.isRunning = false
        state.isComplete = true
    }

    private func resetState(totalSeconds: Int) {
        state.phase = .inhale
        state.phaseSecondsRemaining = phaseLengthSeconds
        state.totalSecondsRemaining = totalSeconds
        state.isRunning = false
        state.isComplete = false
    }

    private func nextPhase(after phase: BreathingPhase) -> BreathingPhase {
        switch phase {
        case .inhale: return .hold1
        case .hold1: return .exhale
        case .exhale: return .hold2
        case .hold2: return .inhale
        }
    }
}
