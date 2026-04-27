import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdvancedDataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @State private var moodEntries: [MoodEntry] = []
    @State private var thoughtRecords: [ThoughtRecord] = []
    @State private var viewModel = AdvancedDataSettingsViewModel()



    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    SettingsSection(title: "Cloud Sync Status") {
                        HStack(spacing: 12) {
                            Image(systemName: CloudSyncMonitor.shared.status.iconName)
                                .font(.system(size: 24))
                                .foregroundStyle(CloudSyncMonitor.shared.status.color)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(CloudSyncMonitor.shared.status.localizedDescription)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                
                                if let lastSync = CloudSyncMonitor.shared.lastSyncDate {
                                    Text(String(localized: "Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))"))
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                } else {
                                    Text(String(localized: "Never synced"))
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                            Spacer()
                            
                            if CloudSyncMonitor.shared.status == .syncing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button {
                                    CloudSyncMonitor.shared.refreshAccountStatus()
                                    HapticManager.shared.lightImpact()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(themeManager.primaryColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    SettingsSection(title: "Advanced Data") {
                        NavigationLink(destination: DataExportView()) {
                            SettingsRow(
                                icon: "square.and.arrow.up",
                                iconColor: themeManager.primaryColor,
                                title: "Export Records",
                                subtitle: "Generate JSON backups or CSV reports"
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.shared.lightImpact()
                            viewModel.showingImportInfo = true
                        } label: {
                            SettingsRow(
                                icon: "square.and.arrow.down",
                                iconColor: themeManager.primaryColor,
                                title: "Import Backup (JSON)"
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)

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
        .task {
            await refreshPreviewData()
        }
    }

    @MainActor
    private func refreshPreviewData() async {
        moodEntries = LaunchSafeFetch.moodEntries(from: modelContext).reversed()
        thoughtRecords = LaunchSafeFetch.thoughtRecords(from: modelContext).reversed()
    }
}
