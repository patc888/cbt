import Foundation
import Observation

enum TimePresentedSheet: String, Identifiable {
    case settings
    case premium

    var id: String { rawValue }
}

@MainActor
@Observable
final class TimeAppState {
    var selectedSection: AppSection
    var selectedDate: Date
    var presentedSheet: TimePresentedSheet?
    var isPresentingAddModal: Bool = false

    init(
        selectedSection: AppSection = .schedule,
        selectedDate: Date = .now,
        presentedSheet: TimePresentedSheet? = nil,
        isPresentingAddModal: Bool = false
    ) {
        self.selectedSection = selectedSection
        self.selectedDate = selectedDate
        self.presentedSheet = presentedSheet
        self.isPresentingAddModal = isPresentingAddModal
    }

    func showSettings() {
        presentedSheet = .settings
    }

    func showPremium() {
        presentedSheet = .premium
    }
}
