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

    private nonisolated static let logger = AppLogger.make(category: "DataExport")

    private init() {}

    /// Exports mood entries to a CSV file on a background task.
    func exportMoodEntries(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        let rows = await MainActor.run {
            let context = ModelContext(container)
            return ids.compactMap { id -> [String]? in
                guard let entry = context.model(for: id) as? MoodEntry else { return nil }
                return [
                    ISO8601DateFormatter().string(from: entry.createdAt),
                    String(entry.moodScore),
                    Self.escapeCSV(entry.emotions.joined(separator: "; ")),
                    Self.escapeCSV(entry.triggers.joined(separator: "; ")),
                    Self.escapeCSV(entry.notes ?? ""),
                    entry.intensity.map { String($0) } ?? ""
                ]
            }
        }

        return await Task.detached(priority: .userInitiated) {
            let headers = ["Date", "Score", "Emotions", "Triggers", "Notes", "Intensity"]
            let csvString = Self.makeCSVString(headers: headers, rows: rows)
            return Self.createCSVFile(name: "MoodEntries", content: csvString)
        }.value
    }

    /// Exports thought records to a CSV file on a background task.
    func exportThoughtRecords(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        let rows = await MainActor.run {
            let context = ModelContext(container)
            return ids.compactMap { id -> [String]? in
                guard let record = context.model(for: id) as? ThoughtRecord else { return nil }
                return [
                    ISO8601DateFormatter().string(from: record.createdAt),
                    Self.escapeCSV(record.situation),
                    Self.escapeCSV(record.automaticThought),
                    Self.escapeCSV(record.emotions.joined(separator: "; ")),
                    Self.escapeCSV(record.distortions.joined(separator: "; ")),
                    Self.escapeCSV(record.evidenceFor),
                    Self.escapeCSV(record.evidenceAgainst),
                    Self.escapeCSV(record.balancedThought),
                    String(record.intensityBefore),
                    String(record.intensityAfter)
                ]
            }
        }

        return await Task.detached(priority: .userInitiated) {
            let headers = [
                "Date", "Situation", "Automatic Thought", "Emotions", "Distortions",
                "Evidence For", "Evidence Against", "Balanced Thought",
                "Intensity Before", "Intensity After"
            ]
            let csvString = Self.makeCSVString(headers: headers, rows: rows)
            return Self.createCSVFile(name: "ThoughtRecords", content: csvString)
        }.value
    }

    /// Exports journal entries to a CSV file on a background task.
    func exportJournalEntries(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        let rows = await MainActor.run {
            let context = ModelContext(container)
            return ids.compactMap { id -> [String]? in
                guard let entry = context.model(for: id) as? JournalEntry else { return nil }
                return [
                    ISO8601DateFormatter().string(from: entry.createdAt),
                    Self.escapeCSV(entry.title),
                    Self.escapeCSV(entry.body),
                    Self.escapeCSV(entry.sourceKind ?? ""),
                    entry.durationSeconds.map { String($0) } ?? ""
                ]
            }
        }

        return await Task.detached(priority: .userInitiated) {
            let headers = ["Date", "Title", "Body", "Source", "Duration (Seconds)"]
            let csvString = Self.makeCSVString(headers: headers, rows: rows)
            return Self.createCSVFile(name: "JournalEntries", content: csvString)
        }.value
    }

    /// Exports exercise history to a CSV file on a background task.
    func exportExerciseCompletions(ids: [PersistentIdentifier], in container: ModelContainer) async -> CSVFile? {
        let rows = await MainActor.run {
            let context = ModelContext(container)
            return ids.compactMap { id -> [String]? in
                guard let completion = context.model(for: id) as? ExerciseCompletion else { return nil }
                return [
                    ISO8601DateFormatter().string(from: completion.createdAt),
                    Self.escapeCSV(completion.exerciseID),
                    Self.escapeCSV(completion.notes ?? "")
                ]
            }
        }

        return await Task.detached(priority: .userInitiated) {
            let headers = ["Date", "ExerciseID", "Notes"]
            let csvString = Self.makeCSVString(headers: headers, rows: rows)
            return Self.createCSVFile(name: "ExerciseHistory", content: csvString)
        }.value
    }

    private nonisolated static func makeCSVString(headers: [String], rows: [[String]]) -> String {
        var csvString = headers.joined(separator: ",") + "\n"
        for row in rows {
            csvString += row.joined(separator: ",") + "\n"
        }
        return csvString
    }

    private nonisolated static func createCSVFile(name: String, content: String) -> CSVFile? {
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

    private nonisolated static func escapeCSV(_ text: String) -> String {
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
