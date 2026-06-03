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
    var showsCloudSyncRow = true
    var showsAdvancedDataOptions = true
    var advancedDataOptionsTitle = "Advanced Data Options"
    var advancedDataOptionsSubtitle = "Import, export, and manage backups"

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(CloudKitSyncMonitor.self) private var syncStatusMonitor
    @AppStorage(AppConfiguration.cloudKitEnabledKey) private var isCloudKitStoreEnabled = false
    @AppStorage(AppConfiguration.cloudKitFailureReasonKey) private var cloudKitFailureReason = ""
    @State private var viewModel = AdvancedDataSettingsViewModel()
    @State private var showingAdvancedDataOptions = false
    @State private var showingStorageAudit = false
    @State private var showingDeletedEntryRecovery = false
    @State private var showingWeeklyReportCheckIn = false
    @State private var showingClearRetentionEventsConfirmation = false
    @State private var retentionEventsClearMessage: String?
    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }) private var moodEntries: [MoodEntry]
    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }) private var thoughtRecords: [ThoughtRecord]
    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == true }, sort: \MoodEntry.createdAt, order: .reverse) private var deletedMoodEntries: [MoodEntry]
    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == true }, sort: \ThoughtRecord.createdAt, order: .reverse) private var deletedThoughtRecords: [ThoughtRecord]
    @Query(filter: #Predicate<JournalEntry> { $0.isDeleted == true }, sort: \JournalEntry.createdAt, order: .reverse) private var deletedJournalEntries: [JournalEntry]
    @Query private var assessmentLogs: [AssessmentLog]

    var body: some View {
        SettingsSection(title: "Data") {
            if showsCloudSyncRow {
                SettingsRow(
                    icon: "icloud.fill",
                    iconColor: themeManager.primaryColor,
                    title: "iCloud Sync",
                    subtitle: cloudSyncSubtitle
                ) {
                    SyncStatusIndicatorView(
                        monitor: syncStatusMonitor,
                        style: isCloudKitStoreEnabled ? .label : .dot
                    )
                }
            }

            SettingsRow(
                icon: "externaldrive.fill",
                iconColor: themeManager.primaryColor,
                title: "Export Backup",
                subtitle: "Save a full CBT JSON backup"
            ) {
                exportBackupControl
            }

            SettingsRow(
                icon: "square.and.arrow.down",
                iconColor: themeManager.primaryColor,
                title: "Import Backup",
                subtitle: "Merge records from a CBT JSON backup"
            ) {
                importBackupControl
            }

            if let operation = viewModel.activeBackupOperation {
                Text(operation.statusText)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 12)
            }
            
            if showsAdvancedDataOptions {
                Button {
                    HapticManager.shared.lightImpact()
                    showingAdvancedDataOptions = true
                } label: {
                    SettingsRow(
                        icon: "slider.horizontal.3",
                        iconColor: themeManager.primaryColor,
                        title: advancedDataOptionsTitle,
                        subtitle: advancedDataOptionsSubtitle
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button {
                HapticManager.shared.lightImpact()
                showingClearRetentionEventsConfirmation = true
            } label: {
                SettingsRow(
                    icon: "chart.bar.doc.horizontal",
                    iconColor: themeManager.primaryColor,
                    title: "Clear Local Analytics",
                    subtitle: "Delete local-only retention events from this device"
                ) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.errorRed)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                HapticManager.shared.lightImpact()
                showingDeletedEntryRecovery = true
            } label: {
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: themeManager.primaryColor,
                    title: "Recently Deleted",
                    subtitle: deletedEntryRecoverySubtitle
                ) {
                    Image(systemName: recoverableDeletedEntryCount == 0 ? "checkmark.circle" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(recoverableDeletedEntryCount == 0 ? Theme.secondaryText : themeManager.primaryColor)
                }
            }
            .buttonStyle(PlainButtonStyle())

#if DEBUG
            NavigationLink(destination: LocalRetentionDashboardView()) {
                SettingsRow(
                    icon: "chart.xyaxis.line",
                    iconColor: themeManager.primaryColor,
                    title: "Local Retention Dashboard",
                    subtitle: "Debug-only local event counts and funnels"
                ) {
                    SettingsDisclosureIndicator()
                }
            }
            .buttonStyle(.plain)
#endif
        }
        .sheet(isPresented: $showingAdvancedDataOptions) {
            advancedDataOptionsSheet
        }
        .sheet(isPresented: $showingDeletedEntryRecovery) {
            DeletedEntryRecoveryView()
                .environment(themeManager)
                .dsSheetPresentation(detents: [.large])
        }
        .sheet(isPresented: $showingWeeklyReportCheckIn) {
            MoodCheckinView()
                .dsSheetPresentation()
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
        .alert("Local Analytics", isPresented: Binding(get: { retentionEventsClearMessage != nil }, set: { if !$0 { retentionEventsClearMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(retentionEventsClearMessage ?? "")
        }
        .confirmationDialog("Clear local analytics?", isPresented: $showingClearRetentionEventsConfirmation, titleVisibility: .visible) {
            Button("Clear Local Analytics", role: .destructive) {
                clearLocalRetentionEvents()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes local-only product analytics events. It does not affect your journal, thought records, mood entries, or reminders.")
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

        if !cloudKitFailureReason.isEmpty {
            return "Using local storage: \(cloudKitFailureReason)"
        }

        return "Using local storage until iCloud is available"
    }

    private var exportBackupControl: some View {
        Group {
            if isExportingBackup {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Export") {
                    HapticManager.shared.mediumImpact()
                    Task {
                        await viewModel.exportData(container: modelContext.container)
                    }
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.primaryColor, hapticType: nil))
                .disabled(viewModel.activeBackupOperation != nil)
            }
        }
    }

    private var importBackupControl: some View {
        Group {
            if isImportingBackup {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("JSON File") {
                    HapticManager.shared.mediumImpact()
                    viewModel.showingFileImporter = true
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.primaryColor, hapticType: nil))
                .disabled(viewModel.activeBackupOperation != nil)
            }
        }
    }

    @MainActor
    private func clearLocalRetentionEvents() {
        do {
            try LocalRetentionEventStore.shared.clearAll()
            HapticManager.shared.success()
            retentionEventsClearMessage = "Local analytics events were cleared from this device."
        } catch {
            retentionEventsClearMessage = "Could not clear local analytics: \(error.localizedDescription)"
        }
    }

    private var isExportingBackup: Bool {
        guard case .exporting = viewModel.activeBackupOperation else { return false }
        return true
    }

    private var isImportingBackup: Bool {
        guard case .importing = viewModel.activeBackupOperation else { return false }
        return true
    }

    private var hasWeeklyReportData: Bool {
        !moodEntries.isEmpty || !thoughtRecords.isEmpty || !assessmentLogs.isEmpty
    }

    private var recoverableDeletedEntryCount: Int {
        deletedMoodEntries.filter(isRecoverable).count
            + deletedThoughtRecords.filter(isRecoverable).count
            + deletedJournalEntries.filter(isRecoverable).count
    }

    private var deletedEntryRecoverySubtitle: String {
        if recoverableDeletedEntryCount == 0 {
            return "No recoverable entries"
        }

        return "\(recoverableDeletedEntryCount) recoverable for \(DeletedEntryRecoveryStore.recoveryWindowDays) days"
    }

    private func isRecoverable<T: SoftDeletableRecord>(_ item: T) -> Bool {
        DeletedEntryRecoveryStore.isWithinRecoveryWindow(
            deletedAt: DeletedEntryRecoveryStore.deletedAt(for: item)
        )
    }

    private var advancedDataOptionsSheet: some View {
        NavigationStack {
            DSSheetContainer(maxContentWidth: 680) {
                ScrollView {
                    VStack(spacing: DSSpacing.large) {
                        advancedDataOptionsContent
                        storageAuditRow
                    }
                    .padding(.vertical, DSSpacing.small)
                }
                .scrollIndicators(.hidden)
            }
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
                SyncStorageAuditView()
                    .environment(themeManager)
            }
        }
        .dsSheetPresentation(detents: [.large])
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

            if hasWeeklyReportData {
                SettingsRow(
                    icon: "doc.richtext.fill",
                    iconColor: themeManager.primaryColor,
                    title: "Weekly Report",
                    subtitle: "Private PDF summary of recent mood, thoughts, and assessments"
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
            } else {
                SupportiveEmptyStateView(
                    systemImage: "doc.richtext",
                    title: "Weekly Report",
                    message: "Add one check-in first, then generate a private PDF once there is something meaningful to summarize.",
                    actionTitle: "Add Check-In",
                    actionSystemImage: "face.smiling"
                ) {
                    HapticManager.shared.lightImpact()
                    showingWeeklyReportCheckIn = true
                }
                .padding(.vertical, 4)
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

private struct DeletedEntryRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == true }, sort: \MoodEntry.createdAt, order: .reverse) private var deletedMoodEntries: [MoodEntry]
    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == true }, sort: \ThoughtRecord.createdAt, order: .reverse) private var deletedThoughtRecords: [ThoughtRecord]
    @Query(filter: #Predicate<JournalEntry> { $0.isDeleted == true }, sort: \JournalEntry.createdAt, order: .reverse) private var deletedJournalEntries: [JournalEntry]

    @State private var recoveryMessage: String?

    private var recoverableMoodEntries: [MoodEntry] {
        deletedMoodEntries.filter(isRecoverable)
    }

    private var recoverableThoughtRecords: [ThoughtRecord] {
        deletedThoughtRecords.filter(isRecoverable)
    }

    private var recoverableJournalEntries: [JournalEntry] {
        deletedJournalEntries.filter(isRecoverable)
    }

    private var hasRecoverableEntries: Bool {
        !recoverableMoodEntries.isEmpty
            || !recoverableThoughtRecords.isEmpty
            || !recoverableJournalEntries.isEmpty
    }

    var body: some View {
        NavigationStack {
            DSSheetContainer(maxContentWidth: 680) {
                ScrollView {
                    VStack(spacing: 16) {
                        if hasRecoverableEntries {
                            recoveryOverview
                            moodRecoverySection
                            thoughtRecoverySection
                            journalRecoverySection
                        } else {
                            SupportiveEmptyStateView(
                                systemImage: "checkmark.circle",
                                title: "Nothing to Recover",
                                message: "Deleted mood check-ins, thought records, and journal entries will appear here for \(DeletedEntryRecoveryStore.recoveryWindowDays) days."
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Recently Deleted")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.primaryColor)
                }
            }
            .alert("Recently Deleted", isPresented: Binding(get: { recoveryMessage != nil }, set: { if !$0 { recoveryMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(recoveryMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var moodRecoverySection: some View {
        if !recoverableMoodEntries.isEmpty {
            SettingsSection(title: "Mood Check-ins") {
                VStack(spacing: 12) {
                    ForEach(recoverableMoodEntries, id: \.id) { entry in
                        DeletedEntryRecoveryRow(
                            icon: "face.smiling",
                            iconColor: themeManager.selectedColor,
                            title: "Mood \(entry.moodScore)/10",
                            subtitle: entry.notes?.isEmpty == false ? entry.notes : entry.emotions.joined(separator: ", "),
                            createdAt: entry.createdAt,
                            deletedAt: DeletedEntryRecoveryStore.deletedAt(for: entry),
                            restore: { restore(entry, label: "Mood check-in") }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var thoughtRecoverySection: some View {
        if !recoverableThoughtRecords.isEmpty {
            SettingsSection(title: "Thought Records") {
                VStack(spacing: 12) {
                    ForEach(recoverableThoughtRecords, id: \.id) { record in
                        DeletedEntryRecoveryRow(
                            icon: "brain",
                            iconColor: themeManager.secondaryColor,
                            title: "Thought Record",
                            subtitle: record.situation.isEmpty ? record.automaticThought : record.situation,
                            createdAt: record.createdAt,
                            deletedAt: DeletedEntryRecoveryStore.deletedAt(for: record),
                            restore: { restore(record, label: "Thought record") }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var journalRecoverySection: some View {
        if !recoverableJournalEntries.isEmpty {
            SettingsSection(title: "Journal Entries") {
                VStack(spacing: 12) {
                    ForEach(recoverableJournalEntries, id: \.id) { entry in
                        DeletedEntryRecoveryRow(
                            icon: "book.pages",
                            iconColor: .orange,
                            title: entry.title.isEmpty ? "Journal Entry" : entry.title,
                            subtitle: entry.body,
                            createdAt: entry.createdAt,
                            deletedAt: DeletedEntryRecoveryStore.deletedAt(for: entry),
                            restore: { restore(entry, label: "Journal entry") }
                        )
                    }
                }
            }
        }
    }

    private var recoveryOverview: some View {
        SettingsSection(title: "Recovery Window") {
            Text("Entries deleted from now on stay recoverable here for \(DeletedEntryRecoveryStore.recoveryWindowDays) days. Older soft-deleted entries without a deletion date can also be restored.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func restore<T: SoftDeletableRecord>(_ item: T, label: String) {
        do {
            try modelContext.cbtStore.restore(item: item)
            HapticManager.shared.success()
            recoveryMessage = "\(label) restored."
        } catch {
            HapticManager.shared.warning()
            recoveryMessage = "Could not restore \(label.lowercased()): \(error.localizedDescription)"
        }
    }

    private func isRecoverable<T: SoftDeletableRecord>(_ item: T) -> Bool {
        DeletedEntryRecoveryStore.isWithinRecoveryWindow(
            deletedAt: DeletedEntryRecoveryStore.deletedAt(for: item)
        )
    }
}

private struct DeletedEntryRecoveryRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let createdAt: Date
    let deletedAt: Date?
    let restore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(metadataText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                restore()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(36), expands: false, tint: iconColor, hapticType: .light))
            .accessibilityLabel("Restore \(title)")
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var metadataText: String {
        let created = createdAt.formatted(date: .abbreviated, time: .shortened)

        guard let expiresAt = DeletedEntryRecoveryStore.recoveryExpiresAt(deletedAt: deletedAt) else {
            return "Created \(created) • Recoverable legacy item"
        }

        return "Created \(created) • Recoverable until \(expiresAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
