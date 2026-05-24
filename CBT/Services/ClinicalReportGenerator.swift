import Foundation
import PDFKit
import SwiftData
import UIKit

@MainActor
struct ClinicalReportGenerator {
    struct Report {
        let generatedAt: Date
        let windows: [WindowSummary]
        let assessmentSummaries: [AssessmentSummary]
        let distortionFrequencies: [Frequency]
        let moodTrend: MoodTrend
    }

    struct WindowSummary {
        let days: Int
        let startDate: Date
        let endDate: Date
        let moodEntryCount: Int
        let averageMoodScore: Double?
        let moodDelta: Double?
        let averageMoodIntensity: Double?
        let thoughtRecordCount: Int
        let averageIntensityBefore: Double?
        let averageIntensityAfter: Double?
        let averageIntensityChange: Double?
        let assessmentCount: Int
    }

    struct AssessmentSummary {
        let assessmentType: String
        let entryCount: Int
        let firstDate: Date
        let firstScore: Double
        let latestDate: Date
        let latestScore: Double
        let change: Double
    }

    struct Frequency {
        let label: String
        let count: Int
        let percentage: Double
    }

    struct MoodTrend {
        let entryCount: Int
        let averageScore: Double?
        let firstPeriodAverage: Double?
        let latestPeriodAverage: Double?
        let change: Double?
        let lowestScore: Int?
        let highestScore: Int?
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func generateReport(from modelContext: ModelContext) throws -> Report {
        let moodEntries = try modelContext.fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodEntry.createdAt)]
            )
        )
        let thoughtRecords = try modelContext.fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt)]
            )
        )
        let assessmentLogs = try modelContext.fetch(
            FetchDescriptor<AssessmentLog>(
                sortBy: [SortDescriptor(\AssessmentLog.date)]
            )
        )

        let now = Date()
        let windows = [30, 60, 90].map { days in
            makeWindowSummary(
                days: days,
                endDate: now,
                moodEntries: moodEntries,
                thoughtRecords: thoughtRecords,
                assessmentLogs: assessmentLogs
            )
        }

        return Report(
            generatedAt: now,
            windows: windows,
            assessmentSummaries: makeAssessmentSummaries(from: assessmentLogs, endDate: now),
            distortionFrequencies: makeDistortionFrequencies(from: thoughtRecords, endDate: now),
            moodTrend: makeMoodTrend(from: moodEntries, endDate: now)
        )
    }

    func generatePDFURL(from modelContext: ModelContext) throws -> URL {
        let report = try generateReport(from: modelContext)
        let data = makePDFData(from: report)
        guard let document = PDFDocument(data: data) else {
            throw ClinicalReportError.pdfCreationFailed
        }

        let filenameDate = Self.filenameFormatter.string(from: report.generatedAt)
        let filename = "CBT-Clinical-Report-\(filenameDate).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        guard document.write(to: fileURL) else {
            throw ClinicalReportError.pdfWriteFailed
        }

        return fileURL
    }

    private func makeWindowSummary(
        days: Int,
        endDate: Date,
        moodEntries: [MoodEntry],
        thoughtRecords: [ThoughtRecord],
        assessmentLogs: [AssessmentLog]
    ) -> WindowSummary {
        let startDate = startDate(forLast: days, endingAt: endDate)
        let moods = moodEntries.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let thoughts = thoughtRecords.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let assessments = assessmentLogs.filter { $0.date >= startDate && $0.date <= endDate }
        let splitDate = startDate.addingTimeInterval(endDate.timeIntervalSince(startDate) / 2)
        let earlyMoods = moods.filter { $0.createdAt < splitDate }
        let recentMoods = moods.filter { $0.createdAt >= splitDate }
        let beforeAverage = average(thoughts.map { Double($0.intensityBefore) })
        let afterAverage = average(thoughts.map { Double($0.intensityAfter) })

        return WindowSummary(
            days: days,
            startDate: startDate,
            endDate: endDate,
            moodEntryCount: moods.count,
            averageMoodScore: average(moods.map { Double($0.moodScore) }),
            moodDelta: delta(from: average(earlyMoods.map { Double($0.moodScore) }), to: average(recentMoods.map { Double($0.moodScore) })),
            averageMoodIntensity: average(moods.compactMap { $0.intensity.map(Double.init) }),
            thoughtRecordCount: thoughts.count,
            averageIntensityBefore: beforeAverage,
            averageIntensityAfter: afterAverage,
            averageIntensityChange: delta(from: beforeAverage, to: afterAverage),
            assessmentCount: assessments.count
        )
    }

    private func makeAssessmentSummaries(from logs: [AssessmentLog], endDate: Date) -> [AssessmentSummary] {
        let startDate = startDate(forLast: 90, endingAt: endDate)
        let recentLogs = logs.filter { $0.date >= startDate && $0.date <= endDate }
        let grouped = Dictionary(grouping: recentLogs, by: \.assessmentType)

        return grouped.compactMap { assessmentType, logs in
            let sorted = logs.sorted { $0.date < $1.date }
            guard let first = sorted.first, let latest = sorted.last else { return nil }
            let firstScore = first.scoreValue ?? Double(first.score)
            let latestScore = latest.scoreValue ?? Double(latest.score)

            return AssessmentSummary(
                assessmentType: assessmentType.isEmpty ? "Unspecified" : assessmentType,
                entryCount: sorted.count,
                firstDate: first.date,
                firstScore: firstScore,
                latestDate: latest.date,
                latestScore: latestScore,
                change: latestScore - firstScore
            )
        }
        .sorted { $0.assessmentType.localizedCaseInsensitiveCompare($1.assessmentType) == .orderedAscending }
    }

    private func makeDistortionFrequencies(from records: [ThoughtRecord], endDate: Date) -> [Frequency] {
        let startDate = startDate(forLast: 90, endingAt: endDate)
        let distortions = records
            .filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
            .flatMap(\.distortions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let counts = Dictionary(grouping: distortions, by: { $0 }).mapValues(\.count)
        let total = max(distortions.count, 1)

        return counts
            .map { Frequency(label: $0.key, count: $0.value, percentage: Double($0.value) / Double(total)) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    private func makeMoodTrend(from entries: [MoodEntry], endDate: Date) -> MoodTrend {
        let startDate = startDate(forLast: 90, endingAt: endDate)
        let moods = entries.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let splitDate = startDate.addingTimeInterval(endDate.timeIntervalSince(startDate) / 2)
        let early = moods.filter { $0.createdAt < splitDate }
        let latest = moods.filter { $0.createdAt >= splitDate }
        let firstAverage = average(early.map { Double($0.moodScore) })
        let latestAverage = average(latest.map { Double($0.moodScore) })

        return MoodTrend(
            entryCount: moods.count,
            averageScore: average(moods.map { Double($0.moodScore) }),
            firstPeriodAverage: firstAverage,
            latestPeriodAverage: latestAverage,
            change: delta(from: firstAverage, to: latestAverage),
            lowestScore: moods.map(\.moodScore).min(),
            highestScore: moods.map(\.moodScore).max()
        )
    }

    private func makePDFData(from report: Report) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: PDFLayout.pageRect)
        return renderer.pdfData { context in
            var page = PDFReportPage(context: context, report: report)
            page.draw()
        }
    }

    private func startDate(forLast days: Int, endingAt endDate: Date) -> Date {
        calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate.addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func delta(from start: Double?, to end: Double?) -> Double? {
        guard let start, let end else { return nil }
        return end - start
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum ClinicalReportError: LocalizedError {
    case pdfCreationFailed
    case pdfWriteFailed

    var errorDescription: String? {
        switch self {
        case .pdfCreationFailed:
            return "The clinical report PDF could not be created."
        case .pdfWriteFailed:
            return "The clinical report PDF could not be written to disk."
        }
    }
}

private struct PDFReportPage {
    let context: UIGraphicsPDFRendererContext
    let report: ClinicalReportGenerator.Report

    private var y: CGFloat = 0

    init(context: UIGraphicsPDFRendererContext, report: ClinicalReportGenerator.Report) {
        self.context = context
        self.report = report
    }

    mutating func draw() {
        beginPage()
        drawHeader()
        drawWindowSummaries()
        drawAssessmentSummaries()
        drawDistortionFrequencies()
        drawMoodTrend()
        drawFooter()
    }

    private mutating func beginPage() {
        context.beginPage()
        y = PDFLayout.margin
    }

    private mutating func ensureSpace(_ height: CGFloat) {
        if y + height > PDFLayout.pageRect.height - PDFLayout.margin - 24 {
            drawFooter()
            beginPage()
        }
    }

    private mutating func drawHeader() {
        drawText("Clinical Progress Report", x: PDFLayout.margin, y: y, width: PDFLayout.contentWidth, font: .systemFont(ofSize: 24, weight: .semibold), color: .label)
        y += 30
        drawText("Generated \(Self.dateTimeFormatter.string(from: report.generatedAt))", x: PDFLayout.margin, y: y, width: PDFLayout.contentWidth, font: .systemFont(ofSize: 10, weight: .regular), color: .secondaryLabel)
        y += 18
        drawRule()
        y += 18
    }

    private mutating func drawWindowSummaries() {
        drawSectionTitle("Progress Summary")
        let columns: [(String, CGFloat)] = [
            ("Window", 58),
            ("Mood n", 52),
            ("Mood avg", 70),
            ("Mood change", 88),
            ("Thought n", 68),
            ("Intensity change", 110),
            ("Assess n", 56)
        ]
        drawTableHeader(columns)

        for summary in report.windows {
            ensureSpace(24)
            let values = [
                "\(summary.days)d",
                "\(summary.moodEntryCount)",
                format(summary.averageMoodScore, suffix: "/10"),
                formatSigned(summary.moodDelta),
                "\(summary.thoughtRecordCount)",
                formatSigned(summary.averageIntensityChange, suffix: " pts"),
                "\(summary.assessmentCount)"
            ]
            drawTableRow(values, columns: columns)
        }
        y += 16
    }

    private mutating func drawAssessmentSummaries() {
        drawSectionTitle("Assessment Scores")
        guard !report.assessmentSummaries.isEmpty else {
            drawEmptyState("No assessment logs recorded in the last 90 days.")
            return
        }

        let columns: [(String, CGFloat)] = [
            ("Assessment", 156),
            ("Entries", 54),
            ("First", 76),
            ("Latest", 76),
            ("Change", 70),
            ("Range", 88)
        ]
        drawTableHeader(columns)

        for summary in report.assessmentSummaries {
            ensureSpace(26)
            let values = [
                summary.assessmentType,
                "\(summary.entryCount)",
                format(summary.firstScore),
                format(summary.latestScore),
                formatSigned(summary.change),
                "\(Self.shortDateFormatter.string(from: summary.firstDate)) - \(Self.shortDateFormatter.string(from: summary.latestDate))"
            ]
            drawTableRow(values, columns: columns)
        }
        y += 16
    }

    private mutating func drawDistortionFrequencies() {
        drawSectionTitle("Cognitive Distortion Frequency")
        guard !report.distortionFrequencies.isEmpty else {
            drawEmptyState("No cognitive distortions recorded in the last 90 days.")
            return
        }

        for frequency in report.distortionFrequencies.prefix(10) {
            ensureSpace(28)
            drawText(frequency.label, x: PDFLayout.margin, y: y, width: 220, font: .systemFont(ofSize: 10, weight: .medium), color: .label)
            drawText("\(frequency.count) (\(Int((frequency.percentage * 100).rounded()))%)", x: PDFLayout.margin + 380, y: y, width: 80, font: .systemFont(ofSize: 10, weight: .regular), color: .secondaryLabel, alignment: .right)

            let barX = PDFLayout.margin + 230
            let barY = y + 3
            let barWidth: CGFloat = 135
            UIColor.systemGray5.setFill()
            UIBezierPath(rect: CGRect(x: barX, y: barY, width: barWidth, height: 7)).fill()
            UIColor.label.setFill()
            UIBezierPath(rect: CGRect(x: barX, y: barY, width: max(2, barWidth * frequency.percentage), height: 7)).fill()
            y += 22
        }
        y += 8
    }

    private mutating func drawMoodTrend() {
        drawSectionTitle("Mood Trend")
        let trend = report.moodTrend
        let columns: [(String, CGFloat)] = [
            ("Entries", 70),
            ("Average", 78),
            ("First half avg", 100),
            ("Latest half avg", 106),
            ("Change", 76),
            ("Range", 70)
        ]
        drawTableHeader(columns)
        drawTableRow(
            [
                "\(trend.entryCount)",
                format(trend.averageScore, suffix: "/10"),
                format(trend.firstPeriodAverage, suffix: "/10"),
                format(trend.latestPeriodAverage, suffix: "/10"),
                formatSigned(trend.change),
                moodRangeText(trend)
            ],
            columns: columns
        )
    }

    private mutating func drawSectionTitle(_ title: String) {
        ensureSpace(42)
        drawText(title, x: PDFLayout.margin, y: y, width: PDFLayout.contentWidth, font: .systemFont(ofSize: 14, weight: .semibold), color: .label)
        y += 22
    }

    private mutating func drawTableHeader(_ columns: [(String, CGFloat)]) {
        ensureSpace(24)
        var x = PDFLayout.margin
        for column in columns {
            drawText(column.0.uppercased(), x: x, y: y, width: column.1, font: .systemFont(ofSize: 8, weight: .semibold), color: .secondaryLabel)
            x += column.1
        }
        y += 16
        drawRule(color: .systemGray4)
        y += 6
    }

    private mutating func drawTableRow(_ values: [String], columns: [(String, CGFloat)]) {
        var x = PDFLayout.margin
        for index in values.indices {
            drawText(values[index], x: x, y: y, width: columns[index].1 - 8, font: .systemFont(ofSize: 9, weight: .regular), color: .label)
            x += columns[index].1
        }
        y += 20
    }

    private mutating func drawEmptyState(_ text: String) {
        ensureSpace(24)
        drawText(text, x: PDFLayout.margin, y: y, width: PDFLayout.contentWidth, font: .systemFont(ofSize: 10, weight: .regular), color: .secondaryLabel)
        y += 30
    }

    private mutating func drawFooter() {
        let footerY = PDFLayout.pageRect.height - PDFLayout.margin + 6
        drawRule(y: footerY - 10, color: .systemGray5)
        drawText("Confidential clinical summary. Generated from local CBT app records.", x: PDFLayout.margin, y: footerY, width: PDFLayout.contentWidth, font: .systemFont(ofSize: 8, weight: .regular), color: .secondaryLabel)
    }

    private mutating func drawRule(y ruleY: CGFloat? = nil, color: UIColor = .systemGray3) {
        let lineY = ruleY ?? y
        color.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: PDFLayout.margin, y: lineY))
        path.addLine(to: CGPoint(x: PDFLayout.pageRect.width - PDFLayout.margin, y: lineY))
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(
            in: CGRect(x: x, y: y, width: width, height: 18),
            withAttributes: attributes
        )
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

    private func moodRangeText(_ trend: ClinicalReportGenerator.MoodTrend) -> String {
        guard let lowest = trend.lowestScore, let highest = trend.highestScore else { return "N/A" }
        return "\(lowest)-\(highest)"
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private enum PDFLayout {
    static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let margin: CGFloat = 54
    static let contentWidth: CGFloat = pageRect.width - (margin * 2)
}
