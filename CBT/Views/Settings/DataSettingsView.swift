import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

struct JSONExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        self.fileURL = URL(fileURLWithPath: "/")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: fileURL)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct PDFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        self.fileURL = URL(fileURLWithPath: "/")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: fileURL)
        return FileWrapper(regularFileWithContents: data)
    }
}

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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct DataSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage(AppConfiguration.cloudKitEnabledKey) private var isCloudKitStoreEnabled = false
    @State private var viewModel = AdvancedDataSettingsViewModel()
    @State private var showingAdvancedDataOptions = false
    @State private var showingStorageAudit = false

    var body: some View {
        SettingsSection(title: "Data") {
            SettingsRow(
                icon: "icloud.fill",
                iconColor: themeManager.primaryColor,
                title: "iCloud Sync",
                subtitle: cloudSyncSubtitle
            ) {
                Image(systemName: isCloudKitStoreEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isCloudKitStoreEnabled ? Theme.successGreen : .orange)
            }
            
            Button {
                HapticManager.shared.lightImpact()
                showingAdvancedDataOptions = true
            } label: {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    iconColor: themeManager.primaryColor,
                    title: "Advanced Data Options",
                    subtitle: "Import, export, and manage backups"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingAdvancedDataOptions) {
            advancedDataOptionsSheet
        }
        .alert("Restore Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .alert("Import Result", isPresented: $viewModel.showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Backup restored successfully.")
        }
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
            case .success:
                HapticManager.shared.success()
            case .failure(let error):
                viewModel.errorMessage = "Failed to export data: \(error.localizedDescription)"
            }
            viewModel.exportDocument = nil
        }
        .fileExporter(
            isPresented: $viewModel.showingPDFExporter,
            document: viewModel.pdfExportDocument,
            contentType: .pdf,
            defaultFilename: "CBT_Progress_Report.pdf"
        ) { result in
            switch result {
            case .success:
                HapticManager.shared.success()
            case .failure(let error):
                viewModel.errorMessage = "Failed to export PDF: \(error.localizedDescription)"
            }
            viewModel.pdfExportDocument = nil
        }
    }

    private var cloudSyncSubtitle: String {
        if isCloudKitStoreEnabled {
            return "Syncing between iPhone, iPad, and Mac"
        }

        return "Temporarily using local storage until iCloud is available"
    }

    private var advancedDataOptionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    advancedDataOptionsContent
                        .padding(.horizontal, 16)
                    storageAuditRow
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .background(Theme.secondaryBackground)
            .navigationTitle("Advanced Data Options")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticManager.shared.lightImpact()
                        showingAdvancedDataOptions = false
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.primaryColor)
                }
            }
            .navigationDestination(isPresented: $showingStorageAudit) {
                SyncStatusView()
                    .environment(themeManager)
            }
        }
        .presentationDetents([.large])
    }

    private var storageAuditRow: some View {
        SettingsSection(title: "Diagnostics") {
            Button {
                HapticManager.shared.lightImpact()
                showingStorageAudit = true
            } label: {
                SettingsRow(
                    icon: "internaldrive.fill",
                    iconColor: themeManager.primaryColor,
                    title: "Sync & Storage Audit",
                    subtitle: "Scan for orphan files, repair database, and check iCloud status"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var advancedDataOptionsContent: some View {
        SettingsSection(title: "Data") {
            SettingsRow(icon: "externaldrive.fill", iconColor: themeManager.primaryColor, title: "Export Backup (.json)", subtitle: "Full record snapshot to Files or iCloud") {
                Button("Export") {
                    HapticManager.shared.mediumImpact()
                    Task {
                        await viewModel.exportData(container: modelContext.container)
                    }
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.primaryColor)
            }

            SettingsRow(
                icon: "doc.richtext.fill",
                iconColor: themeManager.primaryColor,
                title: "Therapist PDF Report",
                subtitle: "Beautiful summary of recent mood & thoughts"
            ) {
                Button("Generate") {
                    HapticManager.shared.mediumImpact()
                    Task {
                        await viewModel.exportPDFReport(modelContext: modelContext)
                    }
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.primaryColor)
            }

            sectionHeaderLabel("IMPORT")

            SettingsRow(icon: "square.and.arrow.down", iconColor: themeManager.primaryColor, title: "Import Backup", subtitle: "Merge records from a CBT JSON backup") {
                Button("JSON File") {
                    HapticManager.shared.mediumImpact()
                    viewModel.showingFileImporter = true
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.primaryColor)
            }

            sectionHeaderLabel("DELETE")

            SettingsRow(icon: "trash", iconColor: Theme.errorRed, title: "Delete All Data", subtitle: "Remove all local and synced CBT records") {
                Button("Delete") {
                    HapticManager.shared.mediumImpact()
                    viewModel.showingDeleteDialog = true
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.red)
            }

            Text("This cannot be undone.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func sectionHeaderLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.secondaryText)
            .tracking(1)
            .padding(.leading, 12)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
