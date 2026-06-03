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
    @State private var selectedWeek: Date

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

    init(weekStart: Date = Date()) {
        _selectedWeek = State(initialValue: weekStart)
    }

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headline
                    weekNavigator

                    if isLoading {
                        weeklyReportLoadingState
                    } else if let report, reportHasEnoughData(report) {
                        reportHeader(report)
                        exportOptions
                        therapySessionPrepSection(report.therapyPrep)
                        reportSections(report)
                    } else if let report {
                        weeklyReportEmptyState(recordCount: reportDataPointCount(report))
                    } else if let errorMessage {
                        weeklyReportErrorState(errorMessage)
                    } else {
                        SupportiveEmptyStateView(
                            systemImage: "doc.badge.exclamationmark",
                            title: "Weekly Report",
                            message: "Add one check-in or thought record for the selected week, then come back to build the PDF summary.",
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
        .onAppear {
            LocalRetentionEventStore.shared.record(
                .weeklyReportViewed,
                sourceScreen: "weekly_report",
                metadata: ["view": "report"]
            )
        }
        .sheet(isPresented: $showingMoodCheckIn) {
            MoodCheckinView()
                .dsSheetPresentation()
        }
        .onChange(of: showingMoodCheckIn) { _, isPresented in
            guard !isPresented else { return }
            Task { await refreshReport() }
        }
        .task(id: "\(selectedWeek.timeIntervalSinceReferenceDate)-\(detailLevel.rawValue)") {
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
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(44), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel("Go back")
            },
            trailing: {
                Button {
                    Task { await exportPDF() }
                } label: {
                    Image(systemName: isExporting ? "clock" : "square.and.arrow.up")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(44), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .disabled(!canExportReport)
                .accessibilityLabel("Share or export weekly report PDF")
            }
        )
    }

    private var weekNavigator: some View {
        DSCardContainer {
            HStack(spacing: 12) {
                Button {
                    moveWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(40), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel("Previous week")

                VStack(spacing: 4) {
                    Text("Week of")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.secondaryText.opacity(0.75))
                        .textCase(.uppercase)

                    Text(selectedWeekRangeText)
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                Button {
                    moveWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(40), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .disabled(!canMoveToNextWeek)
                .accessibilityLabel("Next week")
            }
        }
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
                DSSectionHeader(title: "Share / Export", subtitle: "Save a PDF using the existing weekly report export.")

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
                    Label("Share / Export PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(!canExportReport)
            }
        }
    }

    private var weeklyReportLoadingState: some View {
        DSCardContainer {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(themeManager.selectedColor)

                Text("Preparing weekly report...")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading weekly report")
        }
    }

    private func weeklyReportErrorState(_ message: String) -> some View {
        SupportiveEmptyStateView(
            systemImage: "exclamationmark.triangle.fill",
            title: "Could Not Load Report",
            message: message,
            actionTitle: "Try Again",
            actionSystemImage: "arrow.clockwise"
        ) {
            Task { await refreshReport() }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func weeklyReportEmptyState(recordCount: Int?) -> some View {
        SupportiveEmptyStateView(
            systemImage: "doc.text.magnifyingglass",
            title: "Weekly Report",
            message: weeklyReportEmptyMessage(recordCount: recordCount),
            actionTitle: "Add Check-In",
            actionSystemImage: "face.smiling"
        ) {
            showingMoodCheckIn = true
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func therapySessionPrepSection(_ prep: WeeklyReportGenerator.TherapySessionPrep) -> some View {
        WeeklyReportSection(title: "Therapy Session Prep", systemImage: "person.2.wave.2") {
            WeeklyPrepBulletList(
                title: "Top patterns",
                items: prep.topPatterns,
                emptyText: "Top patterns appear once this week has enough repeated data."
            )

            WeeklyPrepItemList(
                title: "Most useful reframes",
                items: prep.usefulReframes,
                emptyText: detailLevel == .summaryOnly
                    ? "Intensity-reducing reframes appear here when private excerpts are enabled."
                    : "No intensity-reducing reframes recorded this week."
            )

            WeeklyPrepItemList(
                title: "Unresolved thoughts",
                items: prep.unresolvedThoughts,
                emptyText: "No unresolved thought records surfaced this week."
            )

            WeeklyAssessmentChangeList(changes: prep.assessmentChanges)

            WeeklyPrepBulletList(
                title: "3 things to discuss",
                items: prep.discussionPrompts,
                emptyText: "Discussion prompts appear once weekly patterns are available."
            )
        }
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

        WeeklyReportSection(title: "Emotions / Triggers", systemImage: "heart.text.square") {
            WeeklyFrequencyList(title: "Top emotions", frequencies: report.emotionSummary, emptyText: "No emotions recorded this week.")
            WeeklyFrequencyList(title: "Top triggers", frequencies: report.triggerSummary, emptyText: "No triggers recorded this week.")
        }

        WeeklyReportSection(title: "Activity Patterns", systemImage: "calendar.badge.clock") {
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

        WeeklyReportSection(title: "Thought Patterns", systemImage: "brain.head.profile") {
            let thought = report.thoughtRecordSummary
            WeeklySummaryRows(rows: [
                WeeklySummaryRowData(title: "Thought records", value: "\(thought.recordCount)"),
                WeeklySummaryRowData(title: "Average before", value: format(thought.averageIntensityBefore, suffix: "%")),
                WeeklySummaryRowData(title: "Average after", value: format(thought.averageIntensityAfter, suffix: "%")),
                WeeklySummaryRowData(title: "Average change", value: formatSigned(thought.averageIntensityChange, suffix: " points"))
            ])
            WeeklyFrequencyList(title: "Common distortions", frequencies: thought.distortionSummary, emptyText: "No distortions recorded this week.")
            WeeklyFrequencyList(title: "Thought record emotions", frequencies: thought.emotionSummary, emptyText: "No thought record emotions recorded this week.")
        }

        WeeklyReportSection(title: "Exercises and Breathing", systemImage: "figure.mind.and.body") {
            let summary = report.breathingJournalSummary
            WeeklyFrequencyList(title: "Completed exercises", frequencies: report.completedExercises, emptyText: "No CBT exercises completed this week.")
            WeeklySummaryRows(rows: [
                WeeklySummaryRowData(title: "Breathing sessions", value: "\(summary.breathingSessionCount)"),
                WeeklySummaryRowData(title: "Breathing time", value: durationText(seconds: summary.totalBreathingSeconds))
            ])
        }

        WeeklyReportSection(title: "Journal Activity", systemImage: "book.closed") {
            let summary = report.breathingJournalSummary
            WeeklySummaryRows(rows: [
                WeeklySummaryRowData(title: "Journal entries", value: "\(summary.journalEntryCount)"),
                WeeklySummaryRowData(title: "Guided journal entries", value: "\(summary.flexibleJournalEntryCount)"),
                WeeklySummaryRowData(title: "Timed journal entries", value: "\(summary.timedJournalEntryCount)")
            ])
        }

        WeeklyReportSection(title: "Suggested Focus for Next Week", systemImage: "scope") {
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

    private var canExportReport: Bool {
        guard let report else { return false }
        return reportHasEnoughData(report) && !isExporting
    }

    private func reportHasEnoughData(_ report: WeeklyReportGenerator.Report) -> Bool {
        reportDataPointCount(report) >= 2
    }

    private func reportDataPointCount(_ report: WeeklyReportGenerator.Report) -> Int {
        let exerciseCount = report.completedExercises.reduce(0) { $0 + $1.count }
        return report.moodSummary.recordCount +
            report.thoughtRecordSummary.recordCount +
            exerciseCount +
            report.breathingJournalSummary.breathingSessionCount +
            report.breathingJournalSummary.journalEntryCount +
            report.breathingJournalSummary.flexibleJournalEntryCount +
            report.activityPatternSummary.completedPlannedActivities
    }

    private func weeklyReportEmptyMessage(recordCount: Int?) -> String {
        guard let recordCount, recordCount > 0 else {
            return "Start this week's report with one check-in, thought record, exercise, breathing reset, or journal entry."
        }

        let recordWord = recordCount == 1 ? "record" : "records"
        return "This week has \(recordCount) \(recordWord). Add one more check-in, thought record, exercise, breathing reset, or journal entry to make the report useful."
    }

    @MainActor
    private func refreshReport() async {
        isLoading = true
        defer { isLoading = false }

        do {
            report = try WeeklyReportGenerator().generateReport(
                from: modelContext,
                weekStart: selectedWeek,
                includeExcerpts: detailLevel.includesExcerpts
            )
        } catch {
            report = nil
            errorMessage = "Could not load weekly report: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func exportPDF() async {
        guard canExportReport else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let fileURL = try pdfExportService.exportWeeklyReportURL(
                from: modelContext,
                weekStart: selectedWeek,
                includeExcerpts: detailLevel.includesExcerpts
            )
            pdfExportDocument = PDFExportDocument(fileURL: fileURL)
            showingPDFExporter = true
        } catch {
            errorMessage = "Could not generate weekly PDF report: \(error.localizedDescription)"
        }
    }

    private var defaultFilename: String {
        "CBT_Weekly_Report_\(Self.filenameFormatter.string(from: selectedWeekInterval.start)).pdf"
    }

    private func dateRangeText(_ report: WeeklyReportGenerator.Report) -> String {
        formattedRange(start: report.dateRange.start, end: report.dateRange.end)
    }

    private var selectedWeekInterval: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: selectedWeek)
            ?? DateInterval(start: Calendar.current.startOfDay(for: selectedWeek), duration: 7 * 24 * 60 * 60)
    }

    private var selectedWeekRangeText: String {
        formattedRange(start: selectedWeekInterval.start, end: selectedWeekInterval.end)
    }

    private var canMoveToNextWeek: Bool {
        let currentWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Calendar.current.startOfDay(for: Date()), duration: 7 * 24 * 60 * 60)
        return selectedWeekInterval.start < currentWeek.start
    }

    private func moveWeek(by weeks: Int) {
        guard let newDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedWeek) else {
            return
        }

        selectedWeek = newDate
    }

    private func formattedRange(start: Date, end: Date) -> String {
        let inclusiveEnd = Calendar.current.date(byAdding: .second, value: -1, to: end) ?? end
        return "\(start.formatted(date: .abbreviated, time: .omitted)) - \(inclusiveEnd.formatted(date: .abbreviated, time: .omitted))"
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
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle = row.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.secondaryText.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 12)
                    Text(row.value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
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

private struct WeeklyPrepBulletList: View {
    let title: String
    let items: [String]
    let emptyText: String

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DSTypography.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText)

            if items.isEmpty {
                Text(emptyText)
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(themeManager.selectedColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(item)
                                .font(DSTypography.body)
                                .foregroundStyle(Theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct WeeklyPrepItemList: View {
    let title: String
    let items: [WeeklyReportGenerator.SessionPrepItem]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DSTypography.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText)

            if items.isEmpty {
                Text(emptyText)
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.title)
                                    .font(DSTypography.body.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                if let date = item.date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                        .lineLimit(1)
                                }
                            }

                            Text(item.detail)
                                .font(DSTypography.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 8)

                        if index < items.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct WeeklyAssessmentChangeList: View {
    let changes: [WeeklyReportGenerator.AssessmentChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assessment changes")
                .font(DSTypography.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText)

            if changes.isEmpty {
                Text("No assessments were logged this week.")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(changes.enumerated()), id: \.element.id) { index, change in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(change.title)
                                    .font(DSTypography.body.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Text(change.latestScoreText)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                    .lineLimit(1)
                            }

                            Text(changeSubtitle(change))
                                .font(DSTypography.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 8)

                        if index < changes.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func changeSubtitle(_ change: WeeklyReportGenerator.AssessmentChange) -> String {
        let previous = change.previousScoreText.map { "Previous \($0). " } ?? ""
        let interpretation = change.interpretation.map { " \($0)." } ?? ""
        return "\(previous)\(change.changeText).\(interpretation)"
    }
}
