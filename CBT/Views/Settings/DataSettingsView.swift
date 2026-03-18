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

    @State private var exportDocument: JSONExportDocument?
    @State private var showingFileExporter = false
    @State private var showingExportInfo = false
    @State private var showingDeleteDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFileImporter = false
    @State private var showingImportInfo = false
    @State private var deleteMode: DeleteMode = .deleteOnly
    @State private var errorMessage: String?
    @State private var showImportSuccess = false

    private let dataExportService = DataExportService()
    private let dataImportService = DataImportService()

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
                            icon: "square.and.arrow.down",
                            iconColor: themeManager.primaryColor,
                            title: "Import Backup (JSON)"
                        ) {
                            Button("Import") {
                                HapticManager.shared.lightImpact()
                                showingImportInfo = true
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.primaryColor)
                        }

                        Divider()
                            .padding(.vertical, 8)

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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
        .alert("Success", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Data imported successfully.")
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importData(from: url)
            case .failure(let error):
                errorMessage = "Could not select file: \(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "CBT_Backup.json"
        ) { result in
            switch result {
            case .success: break
            case .failure(let error):
                errorMessage = "Failed to export data: \(error.localizedDescription)"
            }
        }
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
        .sheet(isPresented: $showingImportInfo) {
            FeatureModalPresenter {
                DSFeatureModal(
                    title: "Import Your Data",
                    subtitle: "Restore your records from a previously exported JSON backup file.",
                    bullets: [
                        DSBullet(icon: "doc.text.fill", text: "Select a .json file exported from this app"),
                        DSBullet(icon: "plus.circle.fill", text: "New entries will be added to your device"),
                        DSBullet(icon: "arrow.2.squarepath", text: "Duplicates will be automatically skipped")
                    ],
                    primaryTitle: "Select File",
                    primaryAction: {
                        HapticManager.shared.mediumImpact()
                        showingImportInfo = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showingFileImporter = true
                        }
                    },
                    secondaryTitle: "Cancel",
                    secondaryAction: {
                        HapticManager.shared.lightImpact()
                        showingImportInfo = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        showingImportInfo = false
                    }
                )
            }
        }
    }

    private func exportData() {
        do {
            let fileURL = try dataExportService.exportDataFileURL(from: modelContext)
            exportDocument = JSONExportDocument(fileURL: fileURL)
            showingFileExporter = true
        } catch {
            errorMessage = "Could not export data. \(error.localizedDescription)"
        }
    }

    private func importData(from url: URL) {
        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            
            // Defers the call to stopAccessingSecurityScopedResource
            defer { url.stopAccessingSecurityScopedResource() }
            
            try dataImportService.importData(from: url, into: modelContext)
            HapticManager.shared.success()
            showImportSuccess = true
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
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



