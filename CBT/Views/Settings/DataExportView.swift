import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    @Query(filter: #Predicate<MoodEntry> { !$0.isDeleted }, sort: \MoodEntry.createdAt, order: .forward)
    private var moodEntries: [MoodEntry]
    
    @Query(filter: #Predicate<ThoughtRecord> { !$0.isDeleted }, sort: \ThoughtRecord.createdAt, order: .forward)
    private var thoughtRecords: [ThoughtRecord]
    
    @Query(filter: #Predicate<JournalEntry> { !$0.isDeleted }, sort: \JournalEntry.createdAt, order: .forward)
    private var journalEntries: [JournalEntry]
    
    @Query(filter: #Predicate<ExerciseCompletion> { !$0.isDeleted }, sort: \ExerciseCompletion.createdAt, order: .forward)
    private var exerciseCompletions: [ExerciseCompletion]
    
    @State private var viewModel = AdvancedDataSettingsViewModel()
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    backupSection
                    
                    reportsSection
                    
                    Spacer(minLength: 40)
                    
                    PrivacyFooter()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Export Data")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
            exportInfoModal
        }
        .alert("Data Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(themeManager.selectedColor.gradient)
            
            Text("Export Your Records")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            
            Text("Download clinical-friendly reports or a full backup of your data.")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 20)
    }
    
    private var backupSection: some View {
        SettingsSection(title: "Full Backup") {
            SettingsRow(
                icon: "archivebox.fill",
                iconColor: themeManager.primaryColor,
                title: "App Backup (JSON)",
                subtitle: "A complete file of all your data. Use this to move to another device or restore your records."
            ) {
                Button {
                    HapticManager.shared.lightImpact()
                    viewModel.showingExportInfo = true
                } label: {
                    Text("Export")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.primaryColor)
                }
                .disabled(viewModel.activeBackupOperation != nil)
            }
            
            if let op = viewModel.activeBackupOperation, op == .exporting {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(op.statusText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
    
    @State private var exportedMoodCSV: CSVFile?
    @State private var exportedThoughtCSV: CSVFile?
    @State private var exportedJournalCSV: CSVFile?
    @State private var exportedExerciseCSV: CSVFile?
    
    @State private var isExportingCSV = false

    private var reportsSection: some View {
        SettingsSection(title: "Spreadsheet Reports (CSV)") {
            VStack(alignment: .leading, spacing: 0) {
                Text("Export specific categories as human-readable tables for therapy or personal review.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                Divider().padding(.leading, 16)
                
                exportRow(
                    icon: "heart.fill",
                    color: .red,
                    title: "Mood Entries",
                    count: moodEntries.count,
                    csv: $exportedMoodCSV,
                    previewName: "Mood Entries",
                    requestExport: {
                        exportedMoodCSV = await CSVExporter.shared.exportMoodEntries(moodEntries)
                    }
                )
                
                exportRow(
                    icon: "brain.head.profile.fill",
                    color: .blue,
                    title: "Thought Records",
                    count: thoughtRecords.count,
                    csv: $exportedThoughtCSV,
                    previewName: "Thought Records",
                    requestExport: {
                        exportedThoughtCSV = await CSVExporter.shared.exportThoughtRecords(thoughtRecords)
                    }
                )
                
                exportRow(
                    icon: "text.quote",
                    color: .orange,
                    title: "Journal Entries",
                    count: journalEntries.count,
                    csv: $exportedJournalCSV,
                    previewName: "Journal Entries",
                    requestExport: {
                        exportedJournalCSV = await CSVExporter.shared.exportJournalEntries(journalEntries)
                    }
                )
                
                exportRow(
                    icon: "checkmark.seal.fill",
                    color: .green,
                    title: "Exercise History",
                    count: exerciseCompletions.count,
                    csv: $exportedExerciseCSV,
                    previewName: "Exercise History",
                    requestExport: {
                        exportedExerciseCSV = await CSVExporter.shared.exportExerciseCompletions(exerciseCompletions)
                    }
                )
            }
        }
    }
    
    private func exportRow(
        icon: String, 
        color: Color, 
        title: String, 
        count: Int, 
        csv: Binding<CSVFile?>, 
        previewName: String,
        requestExport: @escaping () async -> Void
    ) -> some View {
        SettingsRow(
            icon: icon,
            iconColor: color,
            title: title,
            subtitle: "\(count) \(count == 1 ? "record" : "records")"
        ) {
            Group {
                if let file = csv.wrappedValue {
                    ShareLink(item: file, preview: SharePreview("\(previewName) CSV")) {
                        HStack(spacing: 4) {
                            Text("Share")
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption2)
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.primaryColor)
                    }
                } else if count > 0 {
                    Button {
                        HapticManager.shared.lightImpact()
                        isExportingCSV = true
                        Task {
                            await requestExport()
                            isExportingCSV = false
                        }
                    } label: {
                        if isExportingCSV {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Export")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.primaryColor)
                        }
                    }
                } else {
                    Text("No Data")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
    
    private var exportInfoModal: some View {
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
}
