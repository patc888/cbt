import Foundation
import Combine

@MainActor
final class BreathingPresenter: ObservableObject {
    static let shared = BreathingPresenter()

    @Published var isPresented = false
    @Published var durationSeconds: Int = 60
    @Published var autoStart: Bool = true

    private init() {}

    func present(durationSeconds: Int = 60, autoStart: Bool = true) {
        self.durationSeconds = durationSeconds
        self.autoStart = autoStart
        isPresented = true
    }
}
