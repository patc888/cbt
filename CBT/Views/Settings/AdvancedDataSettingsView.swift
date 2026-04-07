import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdvancedDataSettingsView: View {
    @Query(sort: \MoodEntry.createdAt, order: .forward)
    private var moodEntries: [MoodEntry]

    @Query(sort: \ThoughtRecord.createdAt, order: .forward)
    private var thoughtRecords: [ThoughtRecord]

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var viewModel = AdvancedDataSettingsViewModel()

    private var activeMoodEntries: [MoodEntry] {
        moodEntries.filter { !$0.isDeleted }
    }

    private var activeThoughtRecords: [ThoughtRecord] {
        thoughtRecords.filter { !$0.isDeleted }
    }

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
                                viewModel.showingExportInfo = true
                            }
                            .disabled(viewModel.activeBackupOperation != nil)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.primaryColor)
                        }

                        SettingsRow(
                            icon: "square.and.arrow.down",
                            iconColor: themeManager.primaryColor,
                            title: "Import Backup (JSON)"
                        ) {
                            Button("Import") {
                                HapticManager.shared.lightImpact()
                                viewModel.showingImportInfo = true
                            }
                            .disabled(viewModel.activeBackupOperation != nil)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.primaryColor)
                        }

                        if let op = viewModel.activeBackupOperation {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)

                                Text(op.statusText)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        SettingsRow(
                            icon: "tablecells",
                            iconColor: themeManager.primaryColor,
                            title: "Export Moods (CSV)"
                        ) {
                            if let csv = CSVExporter.shared.exportMoodEntries(activeMoodEntries) {
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
                            if let csv = CSVExporter.shared.exportThoughtRecords(activeThoughtRecords) {
                                ShareLink(item: csv, preview: SharePreview("Thought Records CSV")) {
                                    Text("Export")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(themeManager.primaryColor)
                                }
                            }
                        }

                        Button(role: .destructive) {
                            HapticManager.shared.mediumImpact()
                            viewModel.showingDeleteDialog = true
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog("Delete all data?", isPresented: $viewModel.showingDeleteDialog, titleVisibility: .visible) {
            Button("Delete All Data", role: .destructive) {
                viewModel.deleteMode = .deleteOnly
                viewModel.showingDeleteConfirmation = true
            }

            Button("Delete All + Cancel Reminders", role: .destructive) {
                viewModel.deleteMode = .deleteAndCancelReminders
                viewModel.showingDeleteConfirmation = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your records from this device.")
        }
        .alert("Final Confirmation", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticManager.shared.lightImpact()
            }
            Button("Delete", role: .destructive) {
                HapticManager.shared.destructiveAction()
                viewModel.deleteAllData(mode: viewModel.deleteMode, modelContext: modelContext)
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Data Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Success", isPresented: $viewModel.showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Backup restored successfully.")
        }
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.importData(from: url, container: modelContext.container)
                }
            case .failure(let error):
                viewModel.errorMessage = "Could not select file: \(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $viewModel.showingFileExporter,
            document: viewModel.exportDocument,
            contentType: .json,
            defaultFilename: "CBT_Backup.json"
        ) { result in
            switch result {
            case .success: break
            case .failure(let error):
                viewModel.errorMessage = "Failed to export data: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $viewModel.showingExportInfo) {
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
                        viewModel.showingExportInfo = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            Task {
                                await viewModel.exportData(container: modelContext.container)
                            }
                        }
                    },
                    secondaryTitle: "Cancel",
                    secondaryAction: {
                        HapticManager.shared.lightImpact()
                        viewModel.showingExportInfo = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        viewModel.showingExportInfo = false
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showingImportInfo) {
            FeatureModalPresenter {
                DSFeatureModal(
                    title: "Import Your Data",
                    subtitle: "Restore your records from a previously exported JSON backup file.",
                    bullets: [
                        DSBullet(icon: "doc.text.fill", text: "Select a .json file exported from this app"),
                        DSBullet(icon: "plus.circle.fill", text: "Missing entries will be added to your device"),
                        DSBullet(icon: "arrow.2.squarepath", text: "Matching records will be replaced with the backup version")
                    ],
                    primaryTitle: "Select File",
                    primaryAction: {
                        HapticManager.shared.mediumImpact()
                        viewModel.showingImportInfo = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            viewModel.showingFileImporter = true
                        }
                    },
                    secondaryTitle: "Cancel",
                    secondaryAction: {
                        HapticManager.shared.lightImpact()
                        viewModel.showingImportInfo = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        viewModel.showingImportInfo = false
                    }
                )
            }
        }
    }
}
