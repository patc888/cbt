import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import os

struct CSVFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { csv in
            SentTransferredFile(csv.url)
        }
    }
}

/// A thread-safe utility for exporting data collections as CSV files.
final class CSVExporter: Sendable {
    static let shared = CSVExporter()

    private let logger = AppLogger.make(category: "DataExport")

    private init() {}

    /// Exports mood entries to a CSV file on a background task.
    func exportMoodEntries(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            let headers = ["Date", "Score", "Emotions", "Triggers", "Notes", "Intensity"]
            var csvString = headers.joined(separator: ",") + "\n"
            let dateFormatter = ISO8601DateFormatter()

            for id in ids {
                guard let entry = context.model(for: id) as? MoodEntry else { continue }
                
                let row: [String] = [
                    dateFormatter.string(from: entry.createdAt),
                    String(entry.moodScore),
                    self.escapeCSV(entry.emotions.joined(separator: "; ")),
                    self.escapeCSV(entry.triggers.joined(separator: "; ")),
                    self.escapeCSV(entry.notes ?? ""),
                    entry.intensity.map { String($0) } ?? ""
                ]
                csvString += row.joined(separator: ",") + "\n"
            }

            return self.createCSVFile(name: "MoodEntries", content: csvString)
        }.value
    }

    /// Exports thought records to a CSV file on a background task.
    func exportThoughtRecords(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            let headers = [
                "Date", "Situation", "Automatic Thought", "Emotions", "Distortions",
                "Evidence For", "Evidence Against", "Balanced Thought",
                "Intensity Before", "Intensity After"
            ]
            var csvString = headers.joined(separator: ",") + "\n"
            let dateFormatter = ISO8601DateFormatter()

            for id in ids {
                guard let record = context.model(for: id) as? ThoughtRecord else { continue }
                
                let row: [String] = [
                    dateFormatter.string(from: record.createdAt),
                    self.escapeCSV(record.situation),
                    self.escapeCSV(record.automaticThought),
                    self.escapeCSV(record.emotions.joined(separator: "; ")),
                    self.escapeCSV(record.distortions.joined(separator: "; ")),
                    self.escapeCSV(record.evidenceFor),
                    self.escapeCSV(record.evidenceAgainst),
                    self.escapeCSV(record.balancedThought),
                    String(record.intensityBefore),
                    String(record.intensityAfter)
                ]
                csvString += row.joined(separator: ",") + "\n"
            }

            return self.createCSVFile(name: "ThoughtRecords", content: csvString)
        }.value
    }

    /// Exports journal entries to a CSV file on a background task.
    func exportJournalEntries(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            let headers = ["Date", "Title", "Body", "Source", "Duration (Seconds)"]
            var csvString = headers.joined(separator: ",") + "\n"
            let dateFormatter = ISO8601DateFormatter()

            for id in ids {
                guard let entry = context.model(for: id) as? JournalEntry else { continue }
                
                let row: [String] = [
                    dateFormatter.string(from: entry.createdAt),
                    self.escapeCSV(entry.title),
                    self.escapeCSV(entry.body),
                    self.escapeCSV(entry.sourceKind ?? ""),
                    entry.durationSeconds.map { String($0) } ?? ""
                ]
                csvString += row.joined(separator: ",") + "\n"
            }

            return self.createCSVFile(name: "JournalEntries", content: csvString)
        }.value
    }

    /// Exports exercise history to a CSV file on a background task.
    func exportExerciseCompletions(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        await Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            let headers = ["Date", "ExerciseID", "Notes"]
            var csvString = headers.joined(separator: ",") + "\n"
            let dateFormatter = ISO8601DateFormatter()

            for id in ids {
                guard let completion = context.model(for: id) as? ExerciseCompletion else { continue }
                
                let row: [String] = [
                    dateFormatter.string(from: completion.createdAt),
                    self.escapeCSV(completion.exerciseID),
                    self.escapeCSV(completion.notes ?? "")
                ]
                csvString += row.joined(separator: ",") + "\n"
            }

            return self.createCSVFile(name: "ExerciseHistory", content: csvString)
        }.value
    }

    private func createCSVFile(name: String, content: String) -> CSVFile? {
        let fileName = "\(name)_\(Int(Date().timeIntervalSince1970)).csv"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return CSVFile(url: fileURL)
        } catch {
            logger.error("Failed to write CSV: \(error.localizedDescription, privacy: .public)")
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
