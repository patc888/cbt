import Foundation
import SwiftData

struct DataImportService {
    enum ImportError: Error, LocalizedError {
        case invalidData
        case decodingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "The selected file contains invalid data."
            case .decodingFailed(let error):
                return "Failed to decode backup: \(error.localizedDescription)"
            }
        }
    }

    func importData(from url: URL, into modelContext: ModelContext) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        let payload: CBTDataExportPayload
        do {
            payload = try decoder.decode(CBTDataExportPayload.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error)
        }
        
        // Use a set of existing IDs to avoid duplicates
        let existingMoodIDs = try fetchExistingIDs(MoodEntry.self, in: modelContext)
        let existingThoughtIDs = try fetchExistingIDs(ThoughtRecord.self, in: modelContext)
        let existingCompletionIDs = try fetchExistingIDs(ExerciseCompletion.self, in: modelContext)
        let existingJournalIDs = try fetchExistingIDs(JournalEntry.self, in: modelContext)

        // Mood entries
        for entry in payload.moodEntries {
            if !existingMoodIDs.contains(entry.id) {
                let mood = MoodEntry(
                    id: entry.id,
                    createdAt: entry.createdAt,
                    moodScore: entry.moodScore,
                    emotions: entry.emotions,
                    notes: entry.notes
                )
                modelContext.insert(mood)
            }
        }
        
        // Thought records
        for record in payload.thoughtRecords {
            if !existingThoughtIDs.contains(record.id) {
                let thought = ThoughtRecord(
                    id: record.id,
                    createdAt: record.createdAt,
                    situation: record.situation,
                    automaticThought: record.automaticThought,
                    emotions: record.emotions,
                    distortions: record.distortions,
                    evidenceFor: record.evidenceFor,
                    evidenceAgainst: record.evidenceAgainst,
                    balancedThought: record.balancedThought,
                    intensityBefore: record.intensityBefore,
                    intensityAfter: record.intensityAfter
                )
                modelContext.insert(thought)
            }
        }
        
        // Exercise completions
        for completion in payload.exerciseCompletions {
            if !existingCompletionIDs.contains(completion.id) {
                let exercise = ExerciseCompletion(
                    id: completion.id,
                    createdAt: completion.createdAt,
                    exerciseID: completion.exerciseID,
                    notes: completion.notes
                )
                modelContext.insert(exercise)
            }
        }
        
        // Journal entries (if present in payload)
        if let journalEntries = payload.journalEntries {
            for entry in journalEntries {
                if !existingJournalIDs.contains(entry.id) {
                    let journal = JournalEntry(
                        id: entry.id,
                        createdAt: entry.createdAt,
                        title: entry.title,
                        body: entry.body,
                        sourceKind: entry.sourceKind,
                        sourceID: entry.sourceID,
                        durationSeconds: entry.durationSeconds
                    )
                    modelContext.insert(journal)
                }
            }
        }

        try modelContext.save()
    }
    
    private func fetchExistingIDs<T: SoftDeletableRecord>(_ type: T.Type, in modelContext: ModelContext) throws -> Set<UUID> {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        return Set(items.map { $0.id })
    }
}
