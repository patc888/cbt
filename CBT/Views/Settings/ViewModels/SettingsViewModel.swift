import Foundation
import SwiftData
import SwiftUI
import Observation
import OSLog

@Observable
final class SettingsViewModel {
    private static let logger = AppLogger.make(category: "SettingsViewModel")
    
    var hapticsEnabled: Bool = true
    var appLockEnabled: Bool = false
    var discreetModeEnabled: Bool = false
    var currentIcon: String?
    var journeyOptInMessage: String?
    
    var isInitialized = false
    
    private var modelContext: ModelContext?
    private var settings: UserSettings?

    @MainActor
    func initialize(with context: ModelContext) {
        self.modelContext = context
        refresh(in: context)
    }

    @MainActor
    func refresh(in context: ModelContext) {
        let settings = UserSettings.canonicalSettings(
            from: LaunchSafeFetch.userSettings(from: context, logger: Self.logger)
        )

        self.settings = settings
        self.hapticsEnabled = settings?.hapticsEnabled ?? true
        HapticManager.shared.setEnabled(self.hapticsEnabled)
        self.appLockEnabled = settings?.appLockEnabled ?? false
        self.discreetModeEnabled = settings?.discreetModeEnabled ?? AppConfiguration.discreetModeEnabled()
        AppConfiguration.setDiscreetModeEnabled(self.discreetModeEnabled)
        self.currentIcon = settings?.currentIcon
        self.isInitialized = true
    }

    @MainActor
    func updateHaptics(_ enabled: Bool) {
        hapticsEnabled = enabled
        HapticManager.shared.setEnabled(enabled)
        update { $0.hapticsEnabled = enabled }
    }

    @MainActor
    func updateAppLock(_ enabled: Bool) {
        appLockEnabled = enabled
        update { $0.appLockEnabled = enabled }
        
        // Sync with AppStorage if needed for early launch checks
        UserDefaults.standard.set(enabled, forKey: "appLockEnabled")
    }

    @MainActor
    func updateDiscreetMode(_ enabled: Bool) {
        discreetModeEnabled = enabled
        AppConfiguration.setDiscreetModeEnabled(enabled)
        update { $0.discreetModeEnabled = enabled }

        guard let context = modelContext else { return }
        WidgetSnapshotService.publishSnapshot(from: context)
        Task {
            await DailyReminderService.shared.refreshQuoteOfTheDayIfEnabled()
            await PersonalizedReminderService.shared.refreshEnabledReminders(modelContext: context)
        }
    }

    @MainActor
    func updateIcon(_ iconName: String?) {
        currentIcon = iconName
        update { $0.currentIcon = iconName }
    }

    @MainActor
    func optInToFirstSevenDays() {
        guard let context = modelContext else { return }
        _ = FirstSevenDaysJourneyService.shared.optIn(in: context)
        journeyOptInMessage = "Your First 7 Days journey is ready on Home."
    }

    @MainActor
    private func update(_ block: (UserSettings) -> Void) {
        guard let context = modelContext else { return }

        do {
            let targetSettings: UserSettings
            if let settings {
                targetSettings = settings
            } else {
                let newSettings = UserSettings()
                context.insert(newSettings)
                self.settings = newSettings
                targetSettings = newSettings
            }

            block(targetSettings)
            try context.save()
            Self.logger.info("Successfully saved user settings")
        } catch {
            Self.logger.error("Failed to save user settings: \(error.localizedDescription, privacy: .public)")
            // In a real app, we might want to surface this error to the UI
        }
    }
}
