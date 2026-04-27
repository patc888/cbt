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

    @MainActor
    func importData(from url: URL, into container: ModelContainer) async throws {
        let modelContext = ModelContext(container)
        try importData(from: url, into: modelContext)
    }

    @MainActor
    func importData(from url: URL, into modelContext: ModelContext) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        let payload: CBTDataExportPayload
        do {
            payload = try decoder.decode(CBTDataExportPayload.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error)
        }
        
        // Fetch all existing rows so import can restore records in place when
        // a matching ID already exists locally, including soft-deleted rows.
        var existingMoodsByID = try fetchExistingMoodEntries(in: modelContext)
        var existingThoughtsByID = try fetchExistingThoughtRecords(in: modelContext)
        var existingCompletionsByID = try fetchExistingExerciseCompletions(in: modelContext)
        var existingJournalsByID = try fetchExistingJournalEntries(in: modelContext)

        // Mood entries
        for entry in payload.moodEntries {
            if let existingMood = existingMoodsByID[entry.id] {
                update(existingMood, from: entry)
            } else {
                let mood = MoodEntry(
                    id: entry.id,
                    createdAt: entry.createdAt,
                    moodScore: entry.moodScore,
                    emotions: entry.emotions,
                    triggers: entry.triggers ?? [],
                    notes: entry.notes,
                    intensity: entry.intensity
                )
                modelContext.insert(mood)
                existingMoodsByID[entry.id] = mood
            }
        }
        
        // Thought records
        for record in payload.thoughtRecords {
            if let existingThought = existingThoughtsByID[record.id] {
                update(existingThought, from: record)
            } else {
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
                existingThoughtsByID[record.id] = thought
            }
        }
        
        // Exercise completions
        for completion in payload.exerciseCompletions {
            if let existingCompletion = existingCompletionsByID[completion.id] {
                update(existingCompletion, from: completion)
            } else {
                let exercise = ExerciseCompletion(
                    id: completion.id,
                    createdAt: completion.createdAt,
                    exerciseID: completion.exerciseID,
                    notes: completion.notes
                )
                modelContext.insert(exercise)
                existingCompletionsByID[completion.id] = exercise
            }
        }
        
        // Journal entries (if present in payload)
        if let journalEntries = payload.journalEntries {
            for entry in journalEntries {
                if let existingJournal = existingJournalsByID[entry.id] {
                    update(existingJournal, from: entry)
                } else {
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
                    existingJournalsByID[entry.id] = journal
                }
            }
        }

        try modelContext.save()
    }
    
    private func fetchExistingMoodEntries(in modelContext: ModelContext) throws -> [UUID: MoodEntry] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<MoodEntry>()))
    }

    private func fetchExistingThoughtRecords(in modelContext: ModelContext) throws -> [UUID: ThoughtRecord] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<ThoughtRecord>()))
    }

    private func fetchExistingExerciseCompletions(in modelContext: ModelContext) throws -> [UUID: ExerciseCompletion] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<ExerciseCompletion>()))
    }

    private func fetchExistingJournalEntries(in modelContext: ModelContext) throws -> [UUID: JournalEntry] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<JournalEntry>()))
    }

    private func existingRecordsByID<T: SoftDeletableRecord>(from items: [T]) throws -> [UUID: T] {
        Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private func update(_ mood: MoodEntry, from entry: MoodEntryExport) {
        mood.createdAt = entry.createdAt
        mood.moodScore = MoodEntry.clampMoodScore(entry.moodScore)
        mood.emotions = entry.emotions
        mood.triggers = entry.triggers ?? []
        mood.notes = entry.notes
        mood.intensity = entry.intensity
        mood.isDeleted = false
    }

    private func update(_ thought: ThoughtRecord, from record: ThoughtRecordExport) {
        thought.createdAt = record.createdAt
        thought.situation = record.situation
        thought.automaticThought = record.automaticThought
        thought.emotions = record.emotions
        thought.distortions = record.distortions
        thought.evidenceFor = record.evidenceFor
        thought.evidenceAgainst = record.evidenceAgainst
        thought.balancedThought = record.balancedThought
        thought.intensityBefore = ThoughtRecord.clampIntensity(record.intensityBefore)
        thought.intensityAfter = ThoughtRecord.clampIntensity(record.intensityAfter)
        thought.isDeleted = false
    }

    private func update(_ completion: ExerciseCompletion, from export: ExerciseCompletionExport) {
        completion.createdAt = export.createdAt
        completion.exerciseID = export.exerciseID
        completion.notes = export.notes
        completion.isDeleted = false
    }

    private func update(_ journal: JournalEntry, from entry: JournalEntryExport) {
        journal.createdAt = entry.createdAt
        journal.title = entry.title
        journal.body = entry.body
        journal.sourceKind = entry.sourceKind
        journal.sourceID = entry.sourceID
        journal.durationSeconds = entry.durationSeconds
        journal.isDeleted = false
    }
}
