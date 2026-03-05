import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CSVFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { csv in
            SentTransferredFile(csv.url)
        }
    }
}

final class CSVExporter: Sendable {
    static let shared = CSVExporter()

    private init() {}

    func exportMoodEntries(_ entries: [MoodEntry]) -> CSVFile? {
        let headers = ["Date", "Score", "Emotions", "Triggers", "Notes", "Intensity"]
        var csvString = headers.joined(separator: ",") + "\n"

        let dateFormatter = ISO8601DateFormatter()

        for entry in entries {
            let row: [String] = [
                dateFormatter.string(from: entry.createdAt),
                String(entry.moodScore),
                escapeCSV(entry.emotions.joined(separator: "; ")),
                escapeCSV(entry.triggers.joined(separator: "; ")),
                escapeCSV(entry.notes ?? ""),
                entry.intensity.map { String($0) } ?? ""
            ]
            csvString += row.joined(separator: ",") + "\n"
        }

        return createCSVFile(name: "MoodEntries", content: csvString)
    }

    func exportThoughtRecords(_ records: [ThoughtRecord]) -> CSVFile? {
        let headers = [
            "Date", "Situation", "Automatic Thought", "Emotions", "Distortions",
            "Evidence For", "Evidence Against", "Balanced Thought",
            "Intensity Before", "Intensity After"
        ]
        var csvString = headers.joined(separator: ",") + "\n"

        let dateFormatter = ISO8601DateFormatter()

        for record in records {
            let row: [String] = [
                dateFormatter.string(from: record.createdAt),
                escapeCSV(record.situation),
                escapeCSV(record.automaticThought),
                escapeCSV(record.emotions.joined(separator: "; ")),
                escapeCSV(record.distortions.joined(separator: "; ")),
                escapeCSV(record.evidenceFor),
                escapeCSV(record.evidenceAgainst),
                escapeCSV(record.balancedThought),
                String(record.intensityBefore),
                String(record.intensityAfter)
            ]
            csvString += row.joined(separator: ",") + "\n"
        }

        return createCSVFile(name: "ThoughtRecords", content: csvString)
    }

    private func createCSVFile(name: String, content: String) -> CSVFile? {
        let fileName = "\(name)_\(Int(Date().timeIntervalSince1970)).csv"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return CSVFile(url: fileURL)
        } catch {
            print("Failed to write CSV: \(error)")
            return nil
        }
    }

    private func escapeCSV(_ text: String) -> String {
        let containsComma = text.contains(",")
        let containsNewline = text.contains("\n")
        let containsQuote = text.contains("\"")
        
        var escaped = text
        if containsQuote {
            escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
        }
        
        if containsComma || containsNewline || containsQuote {
            return "\"\(escaped)\""
        }
        
        return text
    }
}
