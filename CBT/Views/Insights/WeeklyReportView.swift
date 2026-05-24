import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum WeeklyReportExportDetail: String, CaseIterable, Identifiable {
    case summaryOnly
    case includeExcerpts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summaryOnly:
            return "Summary only"
        case .includeExcerpts:
            return "Include excerpts"
        }
    }

    var includesExcerpts: Bool {
        self == .includeExcerpts
    }
}

struct WeeklyReportView: View {
    let weekStart: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var detailLevel: WeeklyReportExportDetail = .summaryOnly
    @State private var report: WeeklyReportGenerator.Report?
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showingPDFExporter = false
    @State private var pdfExportDocument: PDFExportDocument?
    @State private var showingMoodCheckIn = false

    private let pdfExportService = PDFExportService()

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headline

                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if let report, reportHasAnyData(report) {
                        reportHeader(report)
                        exportOptions
                        reportSections(report)
                    } else if report != nil {
                        weeklyReportEmptyState
                    } else {
                        SupportiveEmptyStateView(
                            systemImage: "doc.badge.exclamationmark",
                            title: "Weekly Report",
                            message: "Weekly reports summarize check-ins, thought records, exercises, and reflections for the selected week.",
                            actionTitle: "Add Check-In",
                            actionSystemImage: "face.smiling"
                        ) {
                            showingMoodCheckIn = true
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .hideNavigationBar()
        .sheet(isPresented: $showingMoodCheckIn) {
            MoodCheckinView()
        }
        .task(id: "\(weekStart.timeIntervalSinceReferenceDate)-\(detailLevel.rawValue)") {
            await refreshReport()
        }
        .fileExporter(
            isPresented: $showingPDFExporter,
            document: pdfExportDocument,
            contentType: .pdf,
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success:
                HapticManager.shared.success()
            case .failure(let error):
                errorMessage = "Failed to export weekly PDF: \(error.localizedDescription)"
            }
            pdfExportDocument = nil
        }
        .alert("Weekly Report Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var headline: some View {
        TopHeadlineView(
            title: "Weekly Report",
            leading: {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go back")
            },
            trailing: {
                Button {
                    Task { await exportPDF() }
                } label: {
                    Image(systemName: isExporting ? "clock" : "square.and.arrow.up")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(report == nil || isExporting)
                .accessibilityLabel("Export weekly report PDF")
            }
        )
    }

    private func reportHeader(_ report: WeeklyReportGenerator.Report) -> some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text(dateRangeText(report))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)

                Text("Generated \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)

                Divider()

                Text("This report summarizes self-tracking data entered in CBT. It is not a diagnosis, medical advice, or a substitute for care from a qualified clinician.")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var exportOptions: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                DSSectionHeader(title: "PDF Export", subtitle: "Choose how much private text to include.")

                SegmentedToggle(
                    selection: $detailLevel,
                    options: WeeklyReportExportDetail.allCases,
                    fontSize: 11,
                    verticalPadding: 7
                ) { option in
                    Text(option.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }

                Text(detailLevel == .summaryOnly
                    ? "Journal and thought excerpts stay out of the PDF."
                    : "Journal and thought excerpts will be included in the PDF.")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await exportPDF() }
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(isExporting || report == nil)
            }
        }
    }

    private var weeklyReportEmptyState: some View {
        SupportiveEmptyStateView(
            systemImage: "doc.text.magnifyingglass",
            title: "Weekly Report",
            message: "Weekly reports summarize your self-tracking once this week has at least one check-in or practice record.",
            actionTitle: "Add Check-In",
            actionSystemImage: "face.smiling"
        ) {
            showingMoodCheckIn = true
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    @ViewBuilder
    private func reportSections(_ report: WeeklyReportGenerator.Report) -> some View {
        WeeklyReportSection(title: "Mood Summary", systemImage: "face.smiling") {
            let mood = report.moodSummary
            WeeklySummaryRows(rows: [
                WeeklySummaryRowData(title: "Mood records", value: "\(mood.recordCount)", subtitle: "\(mood.activeDays) active mood day\(mood.activeDays == 1 ? "" : "s")"),
                WeeklySummaryRowData(title: "Average mood", value: format(mood.averageScore, suffix: "/10")),
                WeeklySummaryRowData(title: "Mood range", value: moodRangeText(mood)),
                WeeklySummaryRowData(title: "Average intensity", value: format(mood.averageIntensity, suffix: "%")),
                WeeklySummaryRowData(title: "Week shift", value: formatSigned(mood.moodChange, suffix: " points"))
            ])
        }

        WeeklyReportSection(title: "Emotion / Trigger Summary", systemImage: "heart.text.square") {
            WeeklyFrequencyList(title: "Top emotions", frequencies: report.emotionSummary, emptyText: "No emotions recorded this week.")
            WeeklyFrequencyList(title: "Top triggers", frequencies: report.triggerSummary, emptyText: "No triggers recorded this week.")
        }

        WeeklyReportSection(title: "Activity Pattern Summary", systemImage: "calendar.badge.clock") {
            let activity = report.activityPatternSummary
            WeeklySummaryRows(rows: [
                WeeklySummaryRowData(title: "Active days", value: "\(activity.activeDays) of 7"),
                WeeklySummaryRowData(title: "Tracked events", value: "\(activity.totalTrackedEvents)"),
                WeeklySummaryRowData(title: "Busiest day", value: busiestDayText(activity)),
                WeeklySummaryRowData(title: "Completed planned activities", value: "\(activity.completedPlannedActivities)"),
                WeeklySummaryRowData(title: "Average enjoyment", value: format(activity.averageActualEnjoyment, suffix: "/10"))
            ])
            WeeklyFrequencyList(title: "Activity tags", frequencies: activity.activityTagSummary, emptyText: "No activity or context tags recorded this week.")
            WeeklyFrequencyList(title: "Activity categories", frequencies: activity.plannedActivityCategories, emptyText: "No completed planned activities recorded this week.")
        }

        WeeklyReportSection(title: "Thought Record Summary", systemImage: "brain.head.profile") {
            let thought = report.thoughtRecordSummary
            WeeklySummaryRows(rows: [
                WeeklySummaryRowData(title: "Thought records", value: "\(thought.recordCount)"),
                WeeklySummaryRowData(title: "Average before", value: format(thought.averageIntensityBefore, suffix: "%")),
                WeeklySummaryRowData(title: "Average after", value: format(thought.averageIntensityAfter, suffix: "%")),
                WeeklySummaryRowData(title: "Average change", value: formatSigned(thought.averageIntensityChange, suffix: " points"))
            ])
            WeeklyFrequencyList(title: "Common distortions", frequencies: thought.distortionSummary, emptyText: "No distortions recorded this week.")
        }

        WeeklyReportSection(title: "Completed Exercises", systemImage: "figure.mind.and.body") {
            WeeklyFrequencyList(title: nil, frequencies: report.completedExercises, emptyText: "No CBT exercises completed this week.")
        }

        WeeklyReportSection(title: "Breathing / Journal Activity", systemImage: "lungs.fill") {
            let summary = report.breathingJournalSummary
            WeeklySummaryRows(rows: [
                WeeklySummaryRowData(title: "Breathing sessions", value: "\(summary.breathingSessionCount)"),
                WeeklySummaryRowData(title: "Breathing time", value: durationText(seconds: summary.totalBreathingSeconds)),
                WeeklySummaryRowData(title: "Journal entries", value: "\(summary.journalEntryCount)"),
                WeeklySummaryRowData(title: "Guided journal entries", value: "\(summary.flexibleJournalEntryCount)"),
                WeeklySummaryRowData(title: "Timed journal entries", value: "\(summary.timedJournalEntryCount)")
            ])
        }

        WeeklyReportSection(title: "Suggested Focus", systemImage: "scope") {
            if report.suggestedFocus.isEmpty {
                Text("Focus suggestions appear after this week has enough patterns to summarize.")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.suggestedFocus, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(themeManager.selectedColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(suggestion)
                                .font(DSTypography.body)
                                .foregroundStyle(Theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }

        WeeklyReportSection(title: "Journal / Thought Excerpts", systemImage: "quote.bubble") {
            if detailLevel == .summaryOnly {
                Text("Summary only is selected, so private journal and thought excerpts are not shown or exported.")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let excerpts = report.thoughtExcerpts + report.journalExcerpts
                if excerpts.isEmpty {
                    Text("Private excerpts appear here only when this week has journal or thought text and excerpts are enabled.")
                        .font(DSTypography.caption)
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(excerpts) { excerpt in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(excerpt.title) - \(excerpt.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(DSTypography.caption.weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                                Text(excerpt.body)
                                    .font(DSTypography.caption)
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func reportHasAnyData(_ report: WeeklyReportGenerator.Report) -> Bool {
        report.moodSummary.recordCount > 0 ||
        report.activityPatternSummary.totalTrackedEvents > 0 ||
        report.thoughtRecordSummary.recordCount > 0 ||
        !report.completedExercises.isEmpty ||
        report.breathingJournalSummary.breathingSessionCount > 0 ||
        report.breathingJournalSummary.journalEntryCount > 0 ||
        report.breathingJournalSummary.flexibleJournalEntryCount > 0 ||
        report.breathingJournalSummary.timedJournalEntryCount > 0
    }

    @MainActor
    private func refreshReport() async {
        isLoading = true
        defer { isLoading = false }

        do {
            report = try WeeklyReportGenerator().generateReport(
                from: modelContext,
                weekStart: weekStart,
                includeExcerpts: detailLevel.includesExcerpts
            )
        } catch {
            report = nil
            errorMessage = "Could not load weekly report: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func exportPDF() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let fileURL = try pdfExportService.exportWeeklyReportURL(
                from: modelContext,
                weekStart: weekStart,
                includeExcerpts: detailLevel.includesExcerpts
            )
            pdfExportDocument = PDFExportDocument(fileURL: fileURL)
            showingPDFExporter = true
        } catch {
            errorMessage = "Could not generate weekly PDF report: \(error.localizedDescription)"
        }
    }

    private var defaultFilename: String {
        "CBT_Weekly_Report_\(Self.filenameFormatter.string(from: weekStart)).pdf"
    }

    private func dateRangeText(_ report: WeeklyReportGenerator.Report) -> String {
        "\(report.dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(report.displayEndDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func moodRangeText(_ mood: WeeklyReportGenerator.MoodSummary) -> String {
        guard let lowest = mood.lowestScore, let highest = mood.highestScore else { return "N/A" }
        return "\(lowest)-\(highest)/10"
    }

    private func busiestDayText(_ activity: WeeklyReportGenerator.ActivityPatternSummary) -> String {
        guard let busiestDay = activity.busiestDay else { return "N/A" }
        return "\(busiestDay.formatted(.dateTime.weekday(.wide))) (\(activity.busiestDayCount) events)"
    }

    private func durationText(seconds: Int) -> String {
        guard seconds > 0 else { return "0 minutes" }
        let minutes = Double(seconds) / 60.0
        let formatted = Self.numberFormatter.string(from: NSNumber(value: minutes)) ?? String(format: "%.1f", minutes)
        return "\(formatted) minutes"
    }

    private func format(_ value: Double?, suffix: String = "") -> String {
        guard let value else { return "N/A" }
        return "\(Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value))\(suffix)"
    }

    private func formatSigned(_ value: Double?, suffix: String = "") -> String {
        guard let value else { return "N/A" }
        let formatted = Self.numberFormatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.1f", abs(value))
        if value > 0 {
            return "+\(formatted)\(suffix)"
        }
        if value < 0 {
            return "-\(formatted)\(suffix)"
        }
        return "0\(suffix)"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct WeeklyReportSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 22)
                    Text(title)
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content()
            }
        }
    }
}

private struct WeeklySummaryRowData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var subtitle: String?
}

private struct WeeklySummaryRows: View {
    let rows: [WeeklySummaryRowData]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(DSTypography.caption)
                            .foregroundStyle(Theme.secondaryText)

                        if let subtitle = row.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.secondaryText.opacity(0.75))
                        }
                    }
                    Spacer(minLength: 12)
                    Text(row.value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 8)

                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct WeeklyFrequencyList: View {
    let title: String?
    let frequencies: [WeeklyReportGenerator.Frequency]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(DSTypography.caption.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }

            if frequencies.isEmpty {
                Text(emptyText)
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(frequencies.prefix(5).enumerated()), id: \.element.id) { index, frequency in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(frequency.label)
                                .font(DSTypography.body)
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 12)
                            Text("\(frequency.count)")
                                .font(DSTypography.caption.weight(.bold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, 6)

                        if index < min(frequencies.count, 5) - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
