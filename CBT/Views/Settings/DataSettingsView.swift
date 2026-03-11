import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct DataSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DataSettingsSection()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .responsiveMaxWidth()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataSettingsSection: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        SettingsSection(title: "Data") {
            SettingsRow(icon: "icloud.fill", iconColor: themeManager.primaryColor, title: "iCloud Sync", subtitle: "Sync between iPhone, iPad, and Mac") {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.successGreen)
            }
            
            Divider()
                .padding(.vertical, 8)
                
            NavigationLink(destination: AdvancedDataSettingsView()) {
                SettingsRow(
                    icon: "gearshape.2.fill",
                    iconColor: themeManager.primaryColor,
                    title: "Advanced Data",
                    subtitle: "Exports and data management"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct AdvancedDataSettingsView: View {
    private enum DeleteMode {
        case deleteOnly
        case deleteAndCancelReminders
    }

    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var moodEntries: [MoodEntry]

    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var thoughtRecords: [ThoughtRecord]

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingExportInfo = false
    @State private var showingDeleteDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteMode: DeleteMode = .deleteOnly
    @State private var errorMessage: String?

    private let dataExportService = DataExportService()

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Advanced Data") {
                        SettingsRow(
                            icon: "square.and.arrow.up",
                            iconColor: themeManager.primaryColor,
                            title: "Export Backup (JSON)"
                        ) {
                            Button("Export") {
                                HapticManager.shared.lightImpact()
                                showingExportInfo = true
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.primaryColor)
                        }

                        SettingsRow(
                            icon: "tablecells",
                            iconColor: themeManager.primaryColor,
                            title: "Export Moods (CSV)"
                        ) {
                            if let csv = CSVExporter.shared.exportMoodEntries(moodEntries) {
                                ShareLink(item: csv, preview: SharePreview("Mood Entries CSV")) {
                                    Text("Export")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(themeManager.primaryColor)
                                }
                            }
                        }

                        SettingsRow(
                            icon: "tablecells",
                            iconColor: themeManager.primaryColor,
                            title: "Export Thoughts (CSV)"
                        ) {
                            if let csv = CSVExporter.shared.exportThoughtRecords(thoughtRecords) {
                                ShareLink(item: csv, preview: SharePreview("Thought Records CSV")) {
                                    Text("Export")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(themeManager.primaryColor)
                                }
                            }
                        }

                        Button(role: .destructive) {
                            HapticManager.shared.mediumImpact()
                            showingDeleteDialog = true
                        } label: {
                            SettingsRow(
                                icon: "trash",
                                iconColor: Theme.errorRed,
                                title: "Delete All Data",
                                subtitle: "Remove all local entries"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Text("This cannot be undone.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Advanced Data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete all data?", isPresented: $showingDeleteDialog, titleVisibility: .visible) {
            Button("Delete All Data", role: .destructive) {
                deleteMode = .deleteOnly
                showingDeleteConfirmation = true
            }

            Button("Delete All + Cancel Reminders", role: .destructive) {
                deleteMode = .deleteAndCancelReminders
                showingDeleteConfirmation = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your records from this device.")
        }
        .alert("Final Confirmation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticManager.shared.lightImpact()
            }
            Button("Delete", role: .destructive) {
                HapticManager.shared.destructiveAction()
                deleteAllData(mode: deleteMode)
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Data Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingShareSheet) {
            if let exportFileURL {
                ActivityViewController(items: [exportFileURL])
            }
        }
        #endif
        .sheet(isPresented: $showingExportInfo) {
            FeatureModalPresenter {
                DSFeatureModal(
                    title: "Export Your Data",
                    subtitle: "Create a JSON file from your local entries that you can save or share.",
                    bullets: [
                        DSBullet(icon: "checkmark.circle", text: "Includes moods, thought records, and exercises"),
                        DSBullet(icon: "lock.fill", text: "Generated locally on your device"),
                        DSBullet(icon: "square.and.arrow.up", text: "You choose where to share or store it")
                    ],
                    primaryTitle: "Export",
                    primaryAction: {
                        HapticManager.shared.mediumImpact()
                        showingExportInfo = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            exportData()
                        }
                    },
                    secondaryTitle: "Cancel",
                    secondaryAction: {
                        HapticManager.shared.lightImpact()
                        showingExportInfo = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        showingExportInfo = false
                    }
                )
            }
        }
    }

    private func exportData() {
        do {
            let fileURL = try dataExportService.exportDataFileURL(from: modelContext)
            exportFileURL = fileURL
            #if canImport(UIKit)
            showingShareSheet = true
            #endif
        } catch {
            errorMessage = "Could not export data. \(error.localizedDescription)"
        }
    }

    private func deleteAllData(mode: DeleteMode) {
        do {
            let moodEntries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            let thoughtRecords = try modelContext.fetch(FetchDescriptor<ThoughtRecord>())
            let completions = try modelContext.fetch(FetchDescriptor<ExerciseCompletion>())
            let journalEntries = try modelContext.fetch(FetchDescriptor<JournalEntry>())

            for record in moodEntries {
                modelContext.delete(record)
            }

            for record in thoughtRecords {
                modelContext.delete(record)
            }

            for record in completions {
                modelContext.delete(record)
            }

            for record in journalEntries {
                modelContext.delete(record)
            }

            try modelContext.save()

            if mode == .deleteAndCancelReminders {
                Task {
                    await ReminderManager.shared.cancelAllCBTReminders()
                }
            }
        } catch {
            errorMessage = "Could not delete data. \(error.localizedDescription)"
        }
    }
}


#if canImport(UIKit)
private struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
