import Foundation
import Combine

@MainActor
final class BreathingPresenter: ObservableObject {
    static let shared = BreathingPresenter()

    @Published var isPresented = false
    @Published var durationSeconds: Int = 60
    @Published var autoStart: Bool = true
    @Published var pattern: BreathingPattern = .box

    private init() {}

    func present(durationSeconds: Int = 60, autoStart: Bool = true, pattern: BreathingPattern = .box) {
        self.durationSeconds = durationSeconds
        self.autoStart = autoStart
        self.pattern = pattern
        isPresented = true
    }
}
