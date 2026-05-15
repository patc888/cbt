import SwiftUI
import SwiftData
import OSLog

struct PDFExportService {
    private static let logger = Logger(subsystem: "com.cbt.app", category: "PDFExport")

    @MainActor
    func exportPDFReportURL(from modelContext: ModelContext) throws -> URL {
        // 1. Gather data using DataExportService
        let exportService = DataExportService()
        let payload = try exportService.makePayload(from: modelContext)
        
        // 2. Prepare the view
        let reportView = PDFReportView(payload: payload)
        
        // 3. Render PDF
        let renderer = ImageRenderer(content: reportView)
        
        let filenameDate = makeFilenameDateString()
        let filename = "CBT-Report-\(filenameDate).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdfContext = CGContext(fileURL as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            pdfContext.beginPDFPage(nil)
            context(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }
        
        Self.logger.info("PDF Report exported to: \(fileURL.path)")
        return fileURL
    }

    private func makeFilenameDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
