import Foundation
import SwiftData

struct CBTDataStore {
    let modelContext: ModelContext

    @discardableResult
    func insertMoodEntry(
        createdAt: Date = Date(),
        moodScore: Int,
        emotions: [String] = [],
        triggers: [String] = [],
        sensations: [String] = [],
        contextTags: [String] = [],
        activityTags: [String] = [],
        notes: String? = nil,
        intensity: Int? = nil
    ) throws -> MoodEntry {
        let entry = MoodEntry(
            createdAt: createdAt,
            moodScore: moodScore,
            emotions: emotions,
            triggers: triggers,
            sensations: sensations,
            contextTags: contextTags,
            activityTags: activityTags,
            notes: notes,
            intensity: intensity
        )
        modelContext.insert(entry)
        try modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        return entry
    }

    @discardableResult
    func insertThoughtRecord(
        createdAt: Date = Date(),
        situation: String = "",
        automaticThought: String = "",
        emotions: [String] = [],
        distortions: [String] = [],
        evidenceFor: String = "",
        evidenceAgainst: String = "",
        balancedThought: String = "",
        intensityBefore: Int,
        intensityAfter: Int
    ) throws -> ThoughtRecord {
        let record = ThoughtRecord(
            createdAt: createdAt,
            situation: situation,
            automaticThought: automaticThought,
            emotions: emotions,
            distortions: distortions,
            evidenceFor: evidenceFor,
            evidenceAgainst: evidenceAgainst,
            balancedThought: balancedThought,
            intensityBefore: intensityBefore,
            intensityAfter: intensityAfter
        )
        modelContext.insert(record)
        try modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        return record
    }

    @discardableResult
    func insertExerciseCompletion(
        createdAt: Date = Date(),
        exerciseID: String,
        notes: String? = nil
    ) throws -> ExerciseCompletion {
        let completion = ExerciseCompletion(
            createdAt: createdAt,
            exerciseID: exerciseID,
            notes: notes
        )
        modelContext.insert(completion)
        try modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        return completion
    }

    @discardableResult
    func insertJournalEntry(
        createdAt: Date = Date(),
        title: String,
        body: String,
        sourceKind: String? = nil,
        sourceID: String? = nil,
        durationSeconds: Int? = nil
    ) throws -> JournalEntry {
        let entry = JournalEntry(
            createdAt: createdAt,
            title: title,
            body: body,
            sourceKind: sourceKind,
            sourceID: sourceID,
            durationSeconds: durationSeconds
        )
        modelContext.insert(entry)
        try modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        return entry
    }

    @discardableResult
    func insertJournalEntry(
        summary: SessionSummary,
        title: String,
        bodyText: String,
        notes: String,
        tags: Set<String>
    ) throws -> JournalEntry {
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        var contentSections = [bodyText]

        if !normalizedNotes.isEmpty {
            contentSections.append("--- Notes ---\n\(normalizedNotes)")
        }

        if !tags.isEmpty {
            contentSections.append("Tags: \(tags.sorted().joined(separator: ", "))")
        }

        return try insertJournalEntry(
            createdAt: summary.endedAt,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: contentSections.joined(separator: "\n\n"),
            sourceKind: summary.sourceKind.rawValue,
            sourceID: summary.sourceID,
            durationSeconds: summary.durationSeconds
        )
    }

    func softDelete<T: SoftDeletableRecord>(item: T) throws {
        item.isDeleted = true
        try modelContext.save()
    }
}

extension ModelContext {
    var cbtStore: CBTDataStore {
        CBTDataStore(modelContext: self)
    }
}
