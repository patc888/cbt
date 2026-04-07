require "fileutils"

content = File.read("CBT/Views/Settings/DataSettingsView.swift")

# Separate main views
parts = content.split("struct AdvancedDataSettingsView: View {")

advanced_data_view = "struct AdvancedDataSettingsView: View {" + parts[1]

# Write out the ViewModel
view_model = %Q{
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

    private let dataExportService = DataExportService()
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
            errorMessage = "Could not export data. \\(error.localizedDescription)"
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
            errorMessage = "Import failed: \\(error.localizedDescription)"
        }

        activeBackupOperation = nil
    }

    func deleteAllData(mode: DataDeleteMode, modelContext: ModelContext) {
        do {
            let moodEntries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            let thoughtRecords = try modelContext.fetch(FetchDescriptor<ThoughtRecord>())
            let completions = try modelContext.fetch(FetchDescriptor<ExerciseCompletion>())
            let journalEntries = try modelContext.fetch(FetchDescriptor<JournalEntry>())

            for record in moodEntries { modelContext.delete(record) }
            for record in thoughtRecords { modelContext.delete(record) }
            for record in completions { modelContext.delete(record) }
            for record in journalEntries { modelContext.delete(record) }

            try modelContext.save()

            if mode == .deleteAndCancelReminders {
                Task {
                    await ReminderManager.shared.cancelAllCBTReminders()
                }
            }
        } catch {
            errorMessage = "Could not delete data. \\(error.localizedDescription)"
        }
    }
}
}
File.write("CBT/Views/Settings/ViewModels/AdvancedDataSettingsViewModel.swift", view_model.strip + "\n")

# Now transform AdvancedDataSettingsView definition
advanced_data_view.gsub!(/private enum DeleteMode.*?\n    }\n/m, "")
advanced_data_view.gsub!(/private enum BackupOperation.*?\n    }\n/m, "")

advanced_data_view.gsub!(/@State private var exportDocument: JSONExportDocument\?/, "@State private var viewModel = AdvancedDataSettingsViewModel()")
advanced_data_view.gsub!(/@State private var showingFileExporter.*?\n/m, "")
advanced_data_view.gsub!(/@State private var showingExportInfo.*?\n/m, "")
advanced_data_view.gsub!(/@State private var showingDeleteDialog.*?\n/m, "")
advanced_data_view.gsub!(/@State private var showingDeleteConfirmation.*?\n/m, "")
advanced_data_view.gsub!(/@State private var showingFileImporter.*?\n/m, "")
advanced_data_view.gsub!(/@State private var showingImportInfo.*?\n/m, "")
advanced_data_view.gsub!(/@State private var deleteMode: DeleteMode = \.deleteOnly\n/m, "")
advanced_data_view.gsub!(/@State private var errorMessage: String\?.*?\n/m, "")
advanced_data_view.gsub!(/@State private var showImportSuccess.*?\n/m, "")
advanced_data_view.gsub!(/@State private var activeBackupOperation: BackupOperation\?.*?\n/m, "")

advanced_data_view.gsub!(/private let dataExportService = DataExportService\(\)\n/m, "")
advanced_data_view.gsub!(/private let dataImportService = DataImportService\(\)\n/m, "")


advanced_data_view.gsub!(/showingExportInfo/, "viewModel.showingExportInfo")
advanced_data_view.gsub!(/showingFileExporter/, "viewModel.showingFileExporter")
advanced_data_view.gsub!(/showingDeleteDialog/, "viewModel.showingDeleteDialog")
advanced_data_view.gsub!(/showingDeleteConfirmation/, "viewModel.showingDeleteConfirmation")
advanced_data_view.gsub!(/showingFileImporter/, "viewModel.showingFileImporter")
advanced_data_view.gsub!(/showingImportInfo/, "viewModel.showingImportInfo")
advanced_data_view.gsub!(/deleteMode/, "viewModel.deleteMode")
advanced_data_view.gsub!(/errorMessage/, "viewModel.errorMessage")
advanced_data_view.gsub!(/showImportSuccess/, "viewModel.showImportSuccess")
advanced_data_view.gsub!(/activeBackupOperation/, "viewModel.activeBackupOperation")
advanced_data_view.gsub!(/exportDocument/, "viewModel.exportDocument")


# Methods replacing
methods_regex = /@MainActor\s+private func exportData\(\) async \{.*?\n\}\n\n\s*@MainActor\s+private func importData\(from url: URL\) async \{.*?\n\}\n\n\s*private func deleteAllData\(mode: .*?\) \{.*?\n\}/m
advanced_data_view.gsub!(methods_regex, "")


advanced_data_view.gsub!(/exportData\(\)/, "viewModel.exportData(container: modelContext.container)")
advanced_data_view.gsub!(/importData\(from: url\)/, "viewModel.importData(from: url, container: modelContext.container)")
advanced_data_view.gsub!(/deleteAllData\(mode: viewModel.deleteMode\)/, "viewModel.deleteAllData(mode: viewModel.deleteMode, modelContext: modelContext)")
advanced_data_view.gsub!(/\.deleteOnly/, ".deleteOnly")
advanced_data_view.gsub!(/\.deleteAndCancelReminders/, ".deleteAndCancelReminders")

# Write out AdvancedDataSettingsView.swift
new_advanced_data = <<~SWIFT
import SwiftUI
import SwiftData

#{advanced_data_view}
SWIFT

File.write("CBT/Views/Settings/AdvancedDataSettingsView.swift", new_advanced_data.strip + "\n")

# Write out DataSettingsView.swift (remove the AdvancedDataSettingsView from it)
File.write("CBT/Views/Settings/DataSettingsView.swift", parts[0].strip + "\n")

