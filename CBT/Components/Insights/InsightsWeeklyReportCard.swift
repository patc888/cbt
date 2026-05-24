import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum WeeklyReportPDFDetail: String, CaseIterable, Identifiable {
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

struct InsightsWeeklyReportCard: View {
    let report: WeeklyReport?
    let isLoading: Bool
    let errorMessage: String?
    let selectedWeek: Date
    let canMoveForward: Bool
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void
    let onAddCheckIn: () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var pdfDetail: WeeklyReportPDFDetail = .summaryOnly
    @State private var isExportingPDF = false
    @State private var showingPDFExporter = false
    @State private var pdfExportDocument: PDFExportDocument?
    @State private var pdfExportErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(String(localized: "Preparing weekly report..."))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 20)
            } else if errorMessage != nil {
                Text(String(localized: "Weekly report could not load right now."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 12)
            } else if let report {
                reportContent(report)
            } else {
                weeklyReportEmptyState
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
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
                pdfExportErrorMessage = "Failed to export weekly PDF: \(error.localizedDescription)"
            }
            pdfExportDocument = nil
        }
        .alert("Weekly PDF Export", isPresented: Binding(get: { pdfExportErrorMessage != nil }, set: { if !$0 { pdfExportErrorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pdfExportErrorMessage ?? "The weekly report PDF could not be exported.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Weekly Report"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)

                Text(dateRangeText)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button(action: onPreviousWeek) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.selectedColor)
                .accessibilityLabel(String(localized: "Previous week"))

                Button(action: onNextWeek) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveForward ? themeManager.selectedColor : Theme.secondaryText.opacity(0.45))
                .disabled(!canMoveForward)
                .accessibilityLabel(String(localized: "Next week"))

                Button {
                    Task { await exportWeeklyPDF() }
                } label: {
                    Image(systemName: isExportingPDF ? "clock" : "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(canExportReport ? themeManager.selectedColor : Theme.secondaryText.opacity(0.45))
                .disabled(!canExportReport)
                .accessibilityLabel(String(localized: "Export weekly report PDF"))
            }
        }
    }

    @ViewBuilder
    private func reportContent(_ report: WeeklyReport) -> some View {
        if !report.hasAnyData {
            weeklyReportEmptyState
        } else {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    reportValue(title: String(localized: "Check-ins"), value: "\(report.moodCheckInCount)", subtitle: String(localized: "mood"))
                    reportValue(title: String(localized: "Avg Mood"), value: averageMoodText(report.averageMood), subtitle: String(localized: "out of 10"))
                    reportValue(title: String(localized: "Trend"), value: trendValue(report.moodTrend), subtitle: trendSubtitle(report.moodTrend))
                }

                patternSection(report)
                completionSection(report)
                assessmentSection(report.assessmentChanges)
                achievementSection(report.achievementsUnlocked)
                pdfExportSection(report)

                Text(report.suggestedFocusForNextWeek)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if !report.insufficientDataMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.insufficientDataMessages, id: \.self) { message in
                            Label(message, systemImage: "info.circle")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var weeklyReportEmptyState: some View {
        SupportiveEmptyStateView(
            systemImage: "doc.text.magnifyingglass",
            title: String(localized: "Weekly Report"),
            message: String(localized: "Weekly reports summarize check-ins, thought records, exercises, and reflections once this week has something to include."),
            actionTitle: String(localized: "Add Check-In"),
            actionSystemImage: "face.smiling"
        ) {
            onAddCheckIn()
        }
    }

    private var canExportReport: Bool {
        report?.hasAnyData == true && !isExportingPDF
    }

    private func pdfExportSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "PDF Export"))

            SegmentedToggle(
                selection: $pdfDetail,
                options: WeeklyReportPDFDetail.allCases,
                fontSize: 10,
                verticalPadding: 6
            ) { option in
                Text(option.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }

            Text(pdfDetail == .summaryOnly
                ? String(localized: "Journal and thought excerpts stay out of the PDF.")
                : String(localized: "Journal and thought excerpts will be included in the PDF."))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await exportWeeklyPDF() }
            } label: {
                Label(String(localized: "Export PDF"), systemImage: "square.and.arrow.up")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSSecondaryButtonStyle())
            .disabled(isExportingPDF)

            NavigationLink {
                WeeklyReportView(weekStart: report.weekStart)
            } label: {
                Label(String(localized: "Open Report"), systemImage: "doc.text.magnifyingglass")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSSecondaryButtonStyle())
        }
    }

    private func reportValue(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.black))
                .foregroundStyle(Theme.secondaryText.opacity(0.75))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func patternSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "Patterns"))
            reportRow(title: String(localized: "Emotions"), values: report.mostCommonEmotions)
            reportRow(title: String(localized: "Triggers"), values: report.mostCommonTriggers)
            reportRow(title: String(localized: "Activity Tags"), values: report.mostCommonActivityTags)
            reportRow(title: String(localized: "Distortions"), values: report.mostCommonCognitiveDistortions)
        }
    }

    private func completionSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "Completed"))
            countRow(String(localized: "Thought records"), report.thoughtRecordCount)
            countRow(String(localized: "Exercises"), report.exercisesCompleted)
            countRow(String(localized: "Breathing sessions"), report.breathingSessionsCompleted)
            countRow(String(localized: "Guided journals"), report.guidedJournalsCompleted)
            countRow(String(localized: "Planned activities"), report.plannedActivitiesCompleted)
        }
    }

    private func assessmentSection(_ changes: [WeeklyReportAssessmentChange]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "Assessments"))
            if changes.isEmpty {
                Text(String(localized: "No assessment changes recorded this week."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(changes) { change in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(change.assessmentType)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .layoutPriority(1)
                        Spacer()
                        Text(signed(change.change))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(change.summary)
                }
            }
        }
    }

    private func achievementSection(_ achievements: [WeeklyReportAchievementUnlock]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "Achievements"))
            if achievements.isEmpty {
                Text(String(localized: "No achievements unlocked this week."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(achievements) { achievement in
                    Label(achievement.title, systemImage: "star.fill")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded).weight(.black))
            .foregroundStyle(Theme.secondaryText.opacity(0.75))
            .tracking(1.0)
    }

    private func reportRow(title: String, values: [WeeklyReportFrequency]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 92, alignment: .leading)

            if values.isEmpty {
                Text(String(localized: "Not enough data yet"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(values.map { "\($0.label) \($0.count)" }.joined(separator: ", "))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func countRow(_ title: String, _ count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .layoutPriority(1)
            Spacer()
            Text("\(count)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var dateRangeText: String {
        if let report {
            return formattedRange(start: report.weekStart, end: report.weekEnd)
        }

        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedWeek)
            ?? DateInterval(start: Calendar.current.startOfDay(for: selectedWeek), duration: 7 * 24 * 60 * 60)
        return formattedRange(start: interval.start, end: interval.end)
    }

    private func formattedRange(start: Date, end: Date) -> String {
        let inclusiveEnd = Calendar.current.date(byAdding: .second, value: -1, to: end) ?? end
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        let endText = inclusiveEnd.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(startText) - \(endText)"
    }

    @MainActor
    private func exportWeeklyPDF() async {
        guard let report, !isExportingPDF else { return }

        isExportingPDF = true
        defer { isExportingPDF = false }

        do {
            let fileURL = try PDFExportService().exportWeeklyReportURL(
                from: modelContext,
                weekStart: report.weekStart,
                includeExcerpts: pdfDetail.includesExcerpts
            )
            pdfExportDocument = PDFExportDocument(fileURL: fileURL)
            showingPDFExporter = true
        } catch {
            pdfExportErrorMessage = "Could not generate weekly PDF report: \(error.localizedDescription)"
        }
    }

    private var defaultFilename: String {
        let exportDate = report?.weekStart ?? selectedWeek
        return "CBT_Weekly_Report_\(Self.filenameFormatter.string(from: exportDate)).pdf"
    }

    private func averageMoodText(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(1))) ?? "-"
    }

    private func trendValue(_ trend: WeeklyReportMoodTrend) -> String {
        guard let change = trend.change else { return "-" }
        if abs(change) < 0.1 { return "0.0" }
        return signed(change)
    }

    private func trendSubtitle(_ trend: WeeklyReportMoodTrend) -> String {
        switch trend.direction {
        case .higher:
            return String(localized: "higher")
        case .lower:
            return String(localized: "lower")
        case .steady:
            return String(localized: "steady")
        case .unavailable:
            return String(localized: "needs prior week")
        }
    }

    private func signed(_ value: Double) -> String {
        let formatted = abs(value).formatted(.number.precision(.fractionLength(1)))
        if value > 0 {
            return "+\(formatted)"
        } else if value < 0 {
            return "-\(formatted)"
        } else {
            return "0.0"
        }
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
