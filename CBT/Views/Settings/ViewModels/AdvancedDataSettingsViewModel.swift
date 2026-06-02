import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum DataDeleteMode {
    case deleteOnly
    case deleteAndCancelReminders
}

enum BackupOperation {
    case exporting
    case importing

    var statusText: String {
        switch self {
        case .exporting:
            return "Preparing JSON backup..."
        case .importing:
            return "Importing backup..."
        }
    }
}

@Observable
final class AdvancedDataSettingsViewModel {
    var exportDocument: JSONExportDocument?
    var showingFileExporter = false
    var showingExportInfo = false
    var showingDeleteDialog = false
    var showingDeleteConfirmation = false
    var showingFileImporter = false
    var showingImportInfo = false
    var deleteMode: DataDeleteMode = .deleteOnly
    var errorMessage: String?
    var showImportSuccess = false
    var activeBackupOperation: BackupOperation?
    
    var showingPDFExporter = false
    var pdfExportDocument: PDFExportDocument?

    private let dataExportService = DataExportService()
    private let pdfExportService = PDFExportService()
    private let dataImportService = DataImportService()

    @MainActor
    func exportData(container: ModelContainer) async {
        guard activeBackupOperation == nil else { return }
        activeBackupOperation = .exporting

        do {
            let fileURL = try await dataExportService.exportDataFileURL(from: container)
            exportDocument = JSONExportDocument(fileURL: fileURL)
            showingFileExporter = true
        } catch {
            errorMessage = "Could not export data. \(error.localizedDescription)"
        }

        activeBackupOperation = nil
    }

    @MainActor
    func exportPDFReport(modelContext: ModelContext) async {
        guard activeBackupOperation == nil else { return }
        
        do {
            let fileURL = try pdfExportService.exportPDFReportURL(from: modelContext)
            pdfExportDocument = PDFExportDocument(fileURL: fileURL)
            showingPDFExporter = true
        } catch {
            errorMessage = "Could not generate PDF report. \(error.localizedDescription)"
        }
        
        activeBackupOperation = nil
    }

    @MainActor
    func importData(from url: URL, container: ModelContainer) async {
        guard activeBackupOperation == nil else { return }

        do {
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            activeBackupOperation = .importing

            try await dataImportService.importData(from: url, into: container)
            HapticManager.shared.success()
            showImportSuccess = true
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }

        activeBackupOperation = nil
    }

    func deleteAllData(mode: DataDeleteMode, modelContext: ModelContext) {
        do {
            let moodEntries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            let thoughtRecords = try modelContext.fetch(FetchDescriptor<ThoughtRecord>())
            let completions = try modelContext.fetch(FetchDescriptor<ExerciseCompletion>())
            let journalEntries = try modelContext.fetch(FetchDescriptor<JournalEntry>())
            let plannedActivities = try modelContext.fetch(FetchDescriptor<PlannedActivity>())
            let assessmentLogs = try modelContext.fetch(FetchDescriptor<AssessmentLog>())
            let personalityAssessmentLogs = try modelContext.fetch(FetchDescriptor<PersonalityAssessmentLog>())
            let programProgresses = try modelContext.fetch(FetchDescriptor<ProgramProgress>())
            let flexibleJournalEntries = try modelContext.fetch(FetchDescriptor<FlexibleJournalEntry>())
            let moodCheckIns = try modelContext.fetch(FetchDescriptor<MoodCheckIn>())
            let breathingSessions = try modelContext.fetch(FetchDescriptor<BreathingSession>())
            let safetyPlans = try modelContext.fetch(FetchDescriptor<SafetyPlan>())
            let achievements = try modelContext.fetch(FetchDescriptor<Achievement>())
            let libraryItems = try modelContext.fetch(FetchDescriptor<LibraryItem>())
            let courses = try modelContext.fetch(FetchDescriptor<Course>())
            let audioContents = try modelContext.fetch(FetchDescriptor<AudioContent>())
            let userSettings = try modelContext.fetch(FetchDescriptor<UserSettings>())

            for record in moodEntries { modelContext.delete(record) }
            for record in thoughtRecords { modelContext.delete(record) }
            for record in completions { modelContext.delete(record) }
            for record in journalEntries { modelContext.delete(record) }
            for record in plannedActivities { modelContext.delete(record) }
            for record in assessmentLogs { modelContext.delete(record) }
            for record in personalityAssessmentLogs { modelContext.delete(record) }
            for record in programProgresses { modelContext.delete(record) }
            for record in flexibleJournalEntries { modelContext.delete(record) }
            for record in moodCheckIns { modelContext.delete(record) }
            for record in breathingSessions { modelContext.delete(record) }
            for record in safetyPlans { modelContext.delete(record) }
            for record in achievements { modelContext.delete(record) }
            for record in libraryItems { modelContext.delete(record) }
            for record in courses { modelContext.delete(record) }
            for record in audioContents { modelContext.delete(record) }
            for settings in userSettings { modelContext.delete(settings) }

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
