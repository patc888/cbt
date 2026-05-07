import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "TimeDataManagementSettingsView")

struct DataBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct TimeDataManagementSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument: DataBackupDocument?
    
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showImportSuccess = false
    
    var body: some View {
        TimeSettingsSection(
            title: "Data Management"
        ) {
            Button(action: {
                prepareExport()
            }) {
                TimeSettingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: Theme.primaryAccent,
                    title: "Export Backup"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                isImporting = true
            }) {
                TimeSettingsRow(
                    icon: "square.and.arrow.down",
                    iconColor: Theme.primaryAccent,
                    title: "Import Backup"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "TimeBlockingBackup-\(Date.now.formatted(.iso8601).replacingOccurrences(of: ":", with: "-"))"
        ) { result in
            switch result {
            case .success(let url):
                logger.info("Exported data to \(url.path)")
            case .failure(let error):
                logger.error("Export failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("Your data has been successfully imported and merged.")
        }
    }
    
    private func prepareExport() {
        HapticManager.shared.lightImpact()
        do {
            let data = try DataTransferManager.shared.exportData(modelContext: modelContext)
            exportDocument = DataBackupDocument(data: data)
            isExporting = true
        } catch {
            logger.error("Failed to prepare export: \(error.localizedDescription)")
            importErrorMessage = "Failed to prepare export data."
            showImportError = true
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        HapticManager.shared.mediumImpact()
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Could not access the selected file."
                showImportError = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                try DataTransferManager.shared.importData(data: data, modelContext: modelContext)
                showImportSuccess = true
            } catch {
                logger.error("Import failed: \(error.localizedDescription)")
                importErrorMessage = "Failed to import data. Please ensure the file is a valid TimeBlocking backup."
                showImportError = true
            }
            
        case .failure(let error):
            logger.error("Import selection failed: \(error.localizedDescription)")
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}
