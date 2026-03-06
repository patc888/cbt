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
    var phaseSecondsRemaining: Double
    var totalSecondsRemaining: Int
    var isRunning: Bool
    var isComplete: Bool
}

@MainActor
final class BreathingEngine: ObservableObject {
    @Published private(set) var state: BreathingState

    private var pattern: BreathingPattern
    private var configuredDurationSeconds: Int
    private var timer: Timer?

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
    
    func setPattern(_ pattern: BreathingPattern) {
        guard !state.isRunning else { return }
        self.pattern = pattern
        resetState(totalSeconds: configuredDurationSeconds)
    }

    private func startTimer() {
        timer?.invalidate()
        // Use 0.1s interval for smoother transitions if needed, but 1s is fine for totalSeconds.
        // Actually, let's use 0.1s to allow for sub-second phase durations (like 4-7-8 if they were sub-second, though they are usually ints).
        // But the user might want precision.
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
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
}
