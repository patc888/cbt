import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [AppPreferences]

    private var appPreferences: AppPreferences? {
        preferences.first
    }

    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mainContent
                }
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: 600)
            .padding(.top, 50) // Adjust for close button area

            navigationArrow
        }
        .navigationTitle("")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will delete all your schedule blocks and templates. This action cannot be undone.")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.system(size: Theme.fontSizeTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            // 1. Subscription Section
            TimeSubscriptionSettingsView(
                isPremium: appEnvironment.subscriptionStore.isPremium,
                action: {
                    HapticManager.shared.lightImpact()
                    appEnvironment.appState.showPremium()
                }
            )

            // 2. Appearance Section
            TimeAppearanceSettingsView(
                preferences: appPreferences,
                onUpdate: updatePreferences
            )

            // 3. Notifications
            TimeNotificationsSettingsView()

            // 4. Data
            TimeDataSettingsView()

            // 5. Security
            TimeSecuritySettingsView()

            // 8. Overview Layout
            TimeOverviewLayoutSettingsView()

            // 10. About
            TimeAboutSettingsView {
                HapticManager.shared.mediumImpact()
                showingResetAlert = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private var navigationArrow: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            dismiss()
        }) {
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.primaryPurple)
                .padding(8)
                .contentShape(Rectangle())
        }
        .padding(.trailing, 20)
        .padding(.top, 12)
    }

    private func updatePreferences(_ update: (AppPreferences) -> Void) {
        guard let appPreferences else {
            return
        }

        update(appPreferences)
        try? appEnvironment.preferencesStore.save(appPreferences, in: modelContext)
    }

    private func resetAllData() {
        HapticManager.shared.lightImpact()
        do {
            try modelContext.delete(model: TimeBlock.self)
            try modelContext.delete(model: ScheduleTemplate.self)
            try modelContext.delete(model: BlockChecklistItem.self)
            
            if let prefs = appPreferences {
                prefs.defaultBlockDurationMinutes = 60
                prefs.dayStartHour = 6
                prefs.firstWeekday = .monday
                prefs.showsCompletedBlocks = true
            }
            
            try modelContext.save()
        } catch {
            print("Error resetting data: \(error)")
        }
    }
}
