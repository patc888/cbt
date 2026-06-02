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
            try modelContext.deleteAllCBTRecords()

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
