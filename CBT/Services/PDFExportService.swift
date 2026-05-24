import Foundation
import SwiftData
import OSLog

struct PDFExportService {
    private static let logger = Logger(subsystem: "com.cbt.app", category: "PDFExport")

    @MainActor
    func exportPDFReportURL(from modelContext: ModelContext) throws -> URL {
        let fileURL = try ClinicalReportGenerator().generatePDFURL(from: modelContext)
        Self.logger.info("PDF Report exported to: \(fileURL.path)")
        return fileURL
    }

    @MainActor
    func exportWeeklyReportURL(
        from modelContext: ModelContext,
        weekStart: Date,
        includeExcerpts: Bool = false
    ) throws -> URL {
        let fileURL = try WeeklyReportGenerator().generatePDFURL(
            from: modelContext,
            weekStart: weekStart,
            includeExcerpts: includeExcerpts
        )
        Self.logger.info("Weekly PDF Report exported to: \(fileURL.path)")
        return fileURL
    }
}
