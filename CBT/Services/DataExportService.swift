import Foundation
import SwiftData

struct MoodEntryExport: Codable {
    let id: UUID
    let createdAt: Date
    let moodScore: Int
    let emotions: [String]
    let notes: String?
}

struct ThoughtRecordExport: Codable {
    let id: UUID
    let createdAt: Date
    let situation: String
    let automaticThought: String
    let emotions: [String]
    let distortions: [String]
    let evidenceFor: String
    let evidenceAgainst: String
    let balancedThought: String
    let intensityBefore: Int
    let intensityAfter: Int
}

struct ExerciseCompletionExport: Codable {
    let id: UUID
    let createdAt: Date
    let exerciseID: String
    let notes: String?
}

struct CBTDataExportPayload: Codable {
    let exportedAt: String
    let appVersion: String?
    let moodEntries: [MoodEntryExport]
    let thoughtRecords: [ThoughtRecordExport]
    let exerciseCompletions: [ExerciseCompletionExport]
}

struct DataExportService {
    func exportDataFileURL(from modelContext: ModelContext) throws -> URL {
        let payload = try makePayload(from: modelContext)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(payload)

        let filenameDate = Self.filenameDateFormatter.string(from: Date())
        let filename = "CBT-Export-\(filenameDate).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    private func makePayload(from modelContext: ModelContext) throws -> CBTDataExportPayload {
        let moodDescriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { !$0.isDeleted },
            sortBy: [SortDescriptor(\MoodEntry.createdAt)]
        )
        let thoughtDescriptor = FetchDescriptor<ThoughtRecord>(
            predicate: #Predicate<ThoughtRecord> { !$0.isDeleted },
            sortBy: [SortDescriptor(\ThoughtRecord.createdAt)]
        )
        let completionDescriptor = FetchDescriptor<ExerciseCompletion>(
            predicate: #Predicate<ExerciseCompletion> { !$0.isDeleted },
            sortBy: [SortDescriptor(\ExerciseCompletion.createdAt)]
        )

        let moodEntries = try modelContext.fetch(moodDescriptor).map {
            MoodEntryExport(
                id: $0.id,
                createdAt: $0.createdAt,
                moodScore: $0.moodScore,
                emotions: $0.emotions,
                notes: $0.notes
            )
        }

        let thoughtRecords = try modelContext.fetch(thoughtDescriptor).map {
            ThoughtRecordExport(
                id: $0.id,
                createdAt: $0.createdAt,
                situation: $0.situation,
                automaticThought: $0.automaticThought,
                emotions: $0.emotions,
                distortions: $0.distortions,
                evidenceFor: $0.evidenceFor,
                evidenceAgainst: $0.evidenceAgainst,
                balancedThought: $0.balancedThought,
                intensityBefore: $0.intensityBefore,
                intensityAfter: $0.intensityAfter
            )
        }

        let exerciseCompletions = try modelContext.fetch(completionDescriptor).map {
            ExerciseCompletionExport(
                id: $0.id,
                createdAt: $0.createdAt,
                exerciseID: $0.exerciseID,
                notes: $0.notes
            )
        }

        return CBTDataExportPayload(
            exportedAt: Self.exportDateFormatter.string(from: Date()),
            appVersion: Self.appVersion,
            moodEntries: moodEntries,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions
        )
    }

    private static let exportDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()

    private static var appVersion: String? {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let shortVersion, let build, !build.isEmpty {
            return "\(shortVersion) (\(build))"
        }

        return shortVersion
    }
}
