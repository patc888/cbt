import Foundation
import Combine

enum SessionBoundaryPreferences {
    static let enabledKey = "cbt_sessionBoundaryGentleStopEnabled"
    static let minutesKey = "cbt_sessionBoundaryGentleStopMinutes"
    static let defaultMinutes = 10
    static let minuteOptions = [5, 10, 15, 20, 30]

    static func activeReminderSeconds(defaults: UserDefaults = .standard) -> Int? {
        guard defaults.bool(forKey: enabledKey) else { return nil }

        let storedMinutes = defaults.integer(forKey: minutesKey)
        let minutes = storedMinutes > 0 ? storedMinutes : defaultMinutes
        return max(1, minutes) * 60
    }
}

@MainActor
final class TimedSessionManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var isComplete = false
    @Published private(set) var secondsRemaining: Int = 0
    @Published private(set) var totalDuration: Int = 0
    @Published private(set) var summary: SessionSummary?
    @Published var isBoundaryPromptPresented = false

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - Double(secondsRemaining) / Double(totalDuration)
    }

    var elapsedSeconds: Int {
        totalDuration - secondsRemaining
    }

    var formattedRemaining: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    // MARK: - Internal
    private var timer: AnyCancellable?
    private var startDate: Date?
    private var boundaryReminderSeconds: Int?
    private var hasShownBoundaryPrompt = false

    var onComplete: ((SessionSummary) -> Void)?

    // MARK: - Actions
    func start(
        durationSeconds: Int,
        summary: SessionSummary,
        boundaryReminderSeconds: Int? = SessionBoundaryPreferences.activeReminderSeconds()
    ) {
        stop()
        self.totalDuration = durationSeconds
        self.secondsRemaining = durationSeconds
        self.summary = summary
        self.startDate = Date()
        self.boundaryReminderSeconds = boundaryReminderSeconds
        self.hasShownBoundaryPrompt = false
        self.isBoundaryPromptPresented = false
        self.isRunning = true
        self.isPaused = false
        self.isComplete = false
        startTimer()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        timer?.cancel()
        timer = nil
    }

    func resume() {
        guard isRunning, isPaused else { return }
        isBoundaryPromptPresented = false
        isPaused = false
        startTimer()
    }

    func continueAfterBoundaryPrompt() {
        resume()
    }

    func closeBoundaryPrompt() {
        isBoundaryPromptPresented = false
    }

    func endEarly() {
        guard isRunning else { return }
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = false
        isComplete = true
        isBoundaryPromptPresented = false
        finalise()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = false
        isComplete = false
        isBoundaryPromptPresented = false
        secondsRemaining = 0
        totalDuration = 0
        summary = nil
        startDate = nil
        boundaryReminderSeconds = nil
        hasShownBoundaryPrompt = false
    }

    // MARK: - Private
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.secondsRemaining > 1 {
                    self.secondsRemaining -= 1
                    self.showBoundaryPromptIfNeeded()
                } else {
                    self.secondsRemaining = 0
                    self.timer?.cancel()
                    self.timer = nil
                    self.isRunning = false
                    self.isPaused = false
                    self.isComplete = true
                    self.finalise()
                }
            }
    }

    private func finalise() {
        guard var summary = summary else { return }
        summary.endedAt = Date()
        summary.durationSeconds = totalDuration - secondsRemaining
        self.summary = summary
        onComplete?(summary)
    }

    private func showBoundaryPromptIfNeeded() {
        guard let boundaryReminderSeconds,
              !hasShownBoundaryPrompt,
              elapsedSeconds >= boundaryReminderSeconds,
              secondsRemaining > 0
        else {
            return
        }

        hasShownBoundaryPrompt = true
        isBoundaryPromptPresented = true
        isPaused = true
        timer?.cancel()
        timer = nil
    }
}
