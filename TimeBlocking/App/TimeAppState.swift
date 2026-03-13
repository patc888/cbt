import Foundation
import Observation

enum TimePresentedSheet: String, Identifiable {
    case dashboard
    case settings
    case templates
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
        selectedSection = .schedule
        presentedSheet = .settings
    }

    func showDashboard() {
        selectedSection = .schedule
        presentedSheet = .dashboard
    }

    func showTemplates() {
        selectedSection = .schedule
        presentedSheet = .templates
    }

    func showAddBlock() {
        selectedSection = .schedule
        presentedSheet = nil
        isPresentingAddModal = true
    }

    func showScheduleHome() {
        selectedSection = .schedule
        presentedSheet = nil
    }

    func showPremium() {
        presentedSheet = .premium
    }
}
