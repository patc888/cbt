import SwiftUI
import SwiftData

struct DataResetOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var showingLocalConfirm = false
    @State private var showingCloudConfirm = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var localResetErrorMessage: String?
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reset Options")
                            .font(DSTypography.pageTitle)
                            .foregroundStyle(themeManager.primaryColor)

                        Text("Your CBT data is currently stored locally on this device. You can clear the local app database, preferences, and reminders from here.")
                            .font(.body)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Option A
                    SettingsSection(title: "Reset This Device") {
                        Button {
                            HapticManager.shared.mediumImpact()
                            showingLocalConfirm = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reset This Device")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.errorRed)

                                Text(localResetDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Reset iCloud") {
                        Button {
                            HapticManager.shared.destructiveAction()
                            showingCloudConfirm = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Delete Synced iCloud Data")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.errorRed)

                                Text(cloudResetDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }

                }
                .padding()
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Reset Data")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if isProcessing {
                ProgressView("Deleting Data...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .alert("Reset This Device?", isPresented: $showingLocalConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Local Data", role: .destructive) {
                performLocalWipe()
            }
        } message: {
            Text("This will delete all local app data, preferences, and reminders stored on this device.")
        }
        .alert("Delete Synced iCloud Data?", isPresented: $showingCloudConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete iCloud + Local Data", role: .destructive) {
                performCloudWipe()
            }
        } message: {
            Text("This deletes CBT's private CloudKit sync zones and cloud-backed app settings, then clears this device. This cannot be undone.")
        }
        .alert("Reset Unavailable", isPresented: Binding(get: { localResetErrorMessage != nil }, set: { if !$0 { localResetErrorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(localResetErrorMessage ?? "")
        }
    }
    
    private func performLocalWipe() {
        Task { await wipeData() }
    }

    private func performCloudWipe() {
        Task { await wipeCloudAndLocalData() }
    }

    @MainActor
    private func wipeData() async {
        isProcessing = true
        errorMessage = nil

        do {
            try deleteAllSwiftDataRecords()
            DataResetManager.shared.resetLocalPreferences()
            await ReminderManager.shared.cancelAllCBTReminders()

            isProcessing = false
            NotificationCenter.default.post(name: .didResetData, object: nil)
            dismiss()
        } catch {
            isProcessing = false
            errorMessage = "Failed to reset this device: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func wipeCloudAndLocalData() async {
        isProcessing = true
        errorMessage = nil
        localResetErrorMessage = nil

        do {
            try await DataResetManager.shared.deleteCloudDataAndLocalStore()
            try deleteAllSwiftDataRecords()
            DataResetManager.shared.resetLocalPreferences()
            await ReminderManager.shared.cancelAllCBTReminders()

            isProcessing = false
            NotificationCenter.default.post(name: .didResetData, object: nil)
            dismiss()
        } catch {
            isProcessing = false
            localResetErrorMessage = "Failed to delete synced iCloud data: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func deleteAllSwiftDataRecords() throws {
        for record in try modelContext.fetch(FetchDescriptor<MoodEntry>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<ThoughtRecord>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<ExerciseCompletion>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<JournalEntry>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<PlannedActivity>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<AssessmentLog>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<PersonalityAssessmentLog>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<ProgramProgress>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<FlexibleJournalEntry>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<MoodCheckIn>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<BreathingSession>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<SafetyPlan>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<Achievement>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<LibraryItem>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<Course>()) {
            modelContext.delete(record)
        }

        for record in try modelContext.fetch(FetchDescriptor<AudioContent>()) {
            modelContext.delete(record)
        }

        for settings in try modelContext.fetch(FetchDescriptor<UserSettings>()) {
            modelContext.delete(settings)
        }

        try modelContext.save()
    }

    private var localResetDescription: String {
        "Clears local data, preferences, and notifications stored on this device. This action cannot be undone."
    }

    private var cloudResetDescription: String {
        "Deletes CBT's private CloudKit sync data and cloud-backed settings, then clears this device. Requires an available iCloud account."
    }
}
