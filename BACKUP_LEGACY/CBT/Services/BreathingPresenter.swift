import Foundation
import Combine

@MainActor
final class BreathingPresenter: ObservableObject {
    static let shared = BreathingPresenter()

    @Published var isPresented = false
    @Published var durationSeconds: Int = 60
    @Published var autoStart: Bool = true
    @Published var pattern: BreathingPattern = .box
    @Published var showControls: Bool = true
    
    var onComplete: (() -> Void)?
    var onDismiss: (() -> Void)?

    private init() {}

    func present(
        durationSeconds: Int = 60,
        autoStart: Bool = true,
        pattern: BreathingPattern = .box,
        showControls: Bool = true,
        onComplete: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.autoStart = autoStart
        self.pattern = pattern
        self.showControls = showControls
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        isPresented = true
    }
}
