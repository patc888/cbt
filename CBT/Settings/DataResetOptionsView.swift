import SwiftUI
import SwiftData

struct DataResetOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    private var isCloudSyncEnabled: Bool { DataResetManager.isCloudSyncEnabled }

    @State private var showingLocalConfirm = false
    @State private var showingCloudSheet = false
    @State private var cloudConfirmText = ""
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
                            .font(.system(.title2, design: .rounded).weight(.bold))
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
                                    .font(.headline)
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

                    if isCloudSyncEnabled {
                        SettingsSection(title: "Reset Everywhere") {
                            Button {
                                HapticManager.shared.mediumImpact()
                                cloudConfirmText = ""
                                showingCloudSheet = true
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Reset Everywhere (Delete iCloud Data)")
                                        .font(.headline)
                                        .foregroundStyle(Theme.errorRed)

                                    Text("Permanently deletes your data from this device and removes synced records from your private iCloud. This affects all synced devices. This action is permanent and cannot be undone.")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.secondaryText)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        SettingsSection(title: "iCloud Reset") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Unavailable in the current data mode")
                                    .font(.headline)
                                    .foregroundStyle(themeManager.primaryColor)

                                Text("Cloud sync is currently turned off, so CBT cannot delete data from iCloud or other devices from this screen.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 8)
                        }
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
        .alert("Reset Unavailable", isPresented: Binding(get: { localResetErrorMessage != nil }, set: { if !$0 { localResetErrorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(localResetErrorMessage ?? "")
        }
        .sheet(isPresented: $showingCloudSheet) {
            NavigationStack {
                Form {
                    Section {
                        Text("DANGER: This will permanently delete your entire CBT history from this device AND from iCloud storage.")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                        
                        Text("This action is irreversible and will immediately remove your data from all other synchronized devices.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                        
                        Text("Please type DELETE below to confirm.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        
                        TextField("Type DELETE to confirm", text: $cloudConfirmText)
                        #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        #endif
                    }
                    
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            Task { await performGlobalWipe() }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Permanently Delete Data")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(cloudConfirmText.uppercased() != "DELETE")
                    }
                }
                .navigationTitle("Confirm iCloud Deletion")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingCloudSheet = false }
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            #endif
        }
    }
    
    private func performLocalWipe() {
        guard !DataResetManager.isCloudSyncEnabled else {
            localResetErrorMessage = "Local-only reset is unavailable while iCloud sync is active. Use Reset Everywhere to delete synced records from iCloud and this device."
            return
        }

        Task { await wipeData(propagatesThroughCloudKit: false) }
    }
    
    private func performGlobalWipe() async {
        await wipeData(propagatesThroughCloudKit: true)
    }

    @MainActor
    private func wipeData(propagatesThroughCloudKit: Bool) async {
        isProcessing = true
        errorMessage = nil

        do {
            try deleteAllSwiftDataRecords()
            DataResetManager.shared.resetLocalPreferences()
            await ReminderManager.shared.cancelAllCBTReminders()

            if propagatesThroughCloudKit {
                CloudSyncMonitor.shared.refreshAccountStatus()
            }

            isProcessing = false
            showingCloudSheet = false
            NotificationCenter.default.post(name: .didResetData, object: nil)
            dismiss()
        } catch {
            isProcessing = false
            errorMessage = propagatesThroughCloudKit
                ? "Failed to delete iCloud data: \(error.localizedDescription)"
                : "Failed to reset this device: \(error.localizedDescription)"
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

        for settings in try modelContext.fetch(FetchDescriptor<UserSettings>()) {
            modelContext.delete(settings)
        }

        try modelContext.save()
    }

    private var localResetDescription: String {
        if isCloudSyncEnabled {
            "Unavailable while iCloud sync is active because deleting local SwiftData records can sync deletions to iCloud."
        } else {
            "Clears local data, preferences, and notifications stored on this device. This action cannot be undone."
        }
    }
}
