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
        intensity: Int? = nil,
        anxietyStressScore: Int? = nil,
        energyScore: Int? = nil,
        sleepQualityScore: Int? = nil,
        helpedToday: String? = nil
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
            intensity: intensity,
            anxietyStressScore: anxietyStressScore,
            energyScore: energyScore,
            sleepQualityScore: sleepQualityScore,
            helpedToday: helpedToday
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
        intensityAfter: Int,
        isSavedReframe: Bool = false,
        isFavoriteReframe: Bool = false,
        mode: ThoughtRecordMode = .guided,
        isDraft: Bool = false,
        completedAt: Date? = nil
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
            intensityAfter: intensityAfter,
            isSavedReframe: isSavedReframe,
            isFavoriteReframe: isFavoriteReframe,
            savedReframeAt: isSavedReframe || isFavoriteReframe ? createdAt : nil,
            updatedAt: createdAt,
            completedAt: isDraft ? nil : (completedAt ?? createdAt),
            isDraft: isDraft,
            mode: mode
        )
        modelContext.insert(record)
        try modelContext.save()
        if !isDraft {
            AchievementService.shared.evaluateAchievements(in: modelContext)
        }
        return record
    }

    @discardableResult
    func saveThoughtRecordDraft(
        existing record: ThoughtRecord?,
        createdAt: Date = Date(),
        mode: ThoughtRecordMode,
        situation: String,
        automaticThought: String,
        emotions: [String],
        distortions: [String],
        evidenceFor: String,
        evidenceAgainst: String,
        balancedThought: String,
        intensityBefore: Int,
        intensityAfter: Int,
        isSavedReframe: Bool,
        isFavoriteReframe: Bool
    ) throws -> ThoughtRecord {
        let draft = record ?? ThoughtRecord(
            createdAt: createdAt,
            intensityBefore: intensityBefore,
            intensityAfter: intensityAfter,
            isDraft: true,
            mode: mode
        )
        if record == nil {
            modelContext.insert(draft)
        }
        applyThoughtRecordValues(
            to: draft,
            mode: mode,
            situation: situation,
            automaticThought: automaticThought,
            emotions: emotions,
            distortions: distortions,
            evidenceFor: evidenceFor,
            evidenceAgainst: evidenceAgainst,
            balancedThought: balancedThought,
            intensityBefore: intensityBefore,
            intensityAfter: intensityAfter,
            isSavedReframe: isSavedReframe,
            isFavoriteReframe: isFavoriteReframe
        )
        draft.isDraft = true
        draft.completedAt = nil
        try modelContext.save()
        return draft
    }

    @discardableResult
    func completeThoughtRecord(
        _ record: ThoughtRecord?,
        createdAt: Date = Date(),
        mode: ThoughtRecordMode,
        situation: String,
        automaticThought: String,
        emotions: [String],
        distortions: [String],
        evidenceFor: String,
        evidenceAgainst: String,
        balancedThought: String,
        intensityBefore: Int,
        intensityAfter: Int,
        isSavedReframe: Bool,
        isFavoriteReframe: Bool
    ) throws -> ThoughtRecord {
        let completed = try saveThoughtRecordDraft(
            existing: record,
            createdAt: createdAt,
            mode: mode,
            situation: situation,
            automaticThought: automaticThought,
            emotions: emotions,
            distortions: distortions,
            evidenceFor: evidenceFor,
            evidenceAgainst: evidenceAgainst,
            balancedThought: balancedThought,
            intensityBefore: intensityBefore,
            intensityAfter: intensityAfter,
            isSavedReframe: isSavedReframe,
            isFavoriteReframe: isFavoriteReframe
        )
        completed.isDraft = false
        completed.completedAt = Date()
        if completed.isSavedReframe || completed.isFavoriteReframe {
            completed.savedReframeAt = completed.completedAt
            completed.lastReviewedAt = nil
        }
        completed.updatedAt = completed.completedAt ?? Date()
        try modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        return completed
    }

    private func applyThoughtRecordValues(
        to record: ThoughtRecord,
        mode: ThoughtRecordMode,
        situation: String,
        automaticThought: String,
        emotions: [String],
        distortions: [String],
        evidenceFor: String,
        evidenceAgainst: String,
        balancedThought: String,
        intensityBefore: Int,
        intensityAfter: Int,
        isSavedReframe: Bool,
        isFavoriteReframe: Bool
    ) {
        record.mode = mode
        record.situation = situation
        record.automaticThought = automaticThought
        record.emotions = emotions
        record.distortions = distortions
        record.evidenceFor = evidenceFor
        record.evidenceAgainst = evidenceAgainst
        record.balancedThought = balancedThought
        record.intensityBefore = ThoughtRecord.clampIntensity(intensityBefore)
        record.intensityAfter = ThoughtRecord.clampIntensity(intensityAfter)
        if !record.isSavedReframe && (isSavedReframe || isFavoriteReframe) {
            record.savedReframeAt = Date()
        } else if !isSavedReframe && !isFavoriteReframe {
            record.savedReframeAt = nil
            record.reviewDueAt = nil
            record.lastReviewedAt = nil
        }
        record.isSavedReframe = isSavedReframe
        record.isFavoriteReframe = isFavoriteReframe
        record.updatedAt = Date()
    }

    func updateSavedReframe(
        _ record: ThoughtRecord,
        isSaved: Bool,
        reviewedAt: Date? = nil
    ) throws {
        if !record.isSavedReframe && isSaved {
            record.savedReframeAt = Date()
            record.lastReviewedAt = nil
            record.reviewDueAt = Calendar.current.date(byAdding: .day, value: 1, to: record.savedReframeAt ?? Date())
        } else if !isSaved {
            record.savedReframeAt = nil
            record.reviewDueAt = nil
            record.lastReviewedAt = nil
            record.balancedThoughtBeliefLater = nil
            record.balancedThoughtBeliefReviewedAt = nil
        }
        record.isSavedReframe = isSaved
        if !isSaved {
            record.isFavoriteReframe = false
        }
        if let reviewedAt {
            record.lastReviewedAt = reviewedAt
        }
        record.updatedAt = Date()
        try modelContext.save()
    }

    func updateFavoriteReframe(_ record: ThoughtRecord, isFavorite: Bool) throws {
        if !record.isSavedReframe {
            record.savedReframeAt = Date()
            record.lastReviewedAt = nil
            record.reviewDueAt = Calendar.current.date(byAdding: .day, value: 1, to: record.savedReframeAt ?? Date())
        }
        record.isSavedReframe = true
        record.isFavoriteReframe = isFavorite
        if isFavorite, record.situationLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            record.situationLabel = record.followUpSituationLabel
        }
        record.updatedAt = Date()
        try modelContext.save()
    }

    func scheduleReframeFollowUp(_ record: ThoughtRecord, dueAt: Date) throws {
        record.isSavedReframe = true
        if record.savedReframeAt == nil {
            record.savedReframeAt = Date()
        }
        record.reviewDueAt = dueAt
        record.updatedAt = Date()
        try modelContext.save()
    }

    func recordBalancedThoughtBelief(_ record: ThoughtRecord, belief: Int, reviewedAt: Date = Date()) throws {
        record.balancedThoughtBeliefLater = ThoughtRecord.clampIntensity(belief)
        record.balancedThoughtBeliefReviewedAt = reviewedAt
        record.lastReviewedAt = reviewedAt
        record.updatedAt = Date()
        try modelContext.save()
    }

    func linkBehavioralExperiment(_ record: ThoughtRecord, exerciseID: String) throws {
        var linkedIDs = record.linkedExperimentIDs
        if !linkedIDs.contains(exerciseID) {
            linkedIDs.append(exerciseID)
        }
        record.linkedExperimentIDs = linkedIDs
        record.updatedAt = Date()
        try modelContext.save()
    }

    func addRelapsePattern(_ record: ThoughtRecord, pattern: String) throws {
        let normalized = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        var patterns = record.relapsePatterns
        if !patterns.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            patterns.append(normalized)
        }
        record.updatedAt = Date()
        try modelContext.save()
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
    func insertTinyWinCompletion(
        createdAt: Date = Date(),
        winID: String
    ) throws -> TinyWinCompletion {
        let completion = TinyWinCompletion(
            createdAt: createdAt,
            winID: winID
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
        durationSeconds: Int? = nil,
        valueIDs: [String] = []
    ) throws -> JournalEntry {
        let entry = JournalEntry(
            createdAt: createdAt,
            title: title,
            body: body,
            sourceKind: sourceKind,
            sourceID: sourceID,
            durationSeconds: durationSeconds,
            valueIDs: valueIDs
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
        tags: Set<String>,
        valueIDs: [String] = []
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
            durationSeconds: summary.durationSeconds,
            valueIDs: valueIDs
        )
    }

    func softDelete<T: SoftDeletableRecord>(item: T) throws {
        item.isDeleted = true
        DeletedEntryRecoveryStore.recordDeletion(for: item)
        try modelContext.save()
    }

    func restore<T: SoftDeletableRecord>(item: T) throws {
        item.isDeleted = false
        DeletedEntryRecoveryStore.clearDeletion(for: item)
        try modelContext.save()
    }
}

enum DeletedEntryRecoveryStore {
    static let recoveryWindowDays = 30

    private static let defaultsKey = "DeletedEntryRecoveryStore.entries.v1"
    private static let recoveryWindow: TimeInterval = 30 * 24 * 60 * 60

    static func recordDeletion<T: SoftDeletableRecord>(for item: T, now: Date = Date(), defaults: UserDefaults = .standard) {
        var entries = loadEntries(defaults: defaults)
        entries[key(for: item)] = now
        save(entries, defaults: defaults)
    }

    static func clearDeletion<T: SoftDeletableRecord>(for item: T, defaults: UserDefaults = .standard) {
        var entries = loadEntries(defaults: defaults)
        entries.removeValue(forKey: key(for: item))
        save(entries, defaults: defaults)
    }

    static func deletedAt<T: SoftDeletableRecord>(for item: T, defaults: UserDefaults = .standard) -> Date? {
        loadEntries(defaults: defaults)[key(for: item)]
    }

    static func isWithinRecoveryWindow(deletedAt: Date?, now: Date = Date()) -> Bool {
        guard let deletedAt else {
            return true
        }

        return now.timeIntervalSince(deletedAt) <= recoveryWindow
    }

    static func recoveryExpiresAt(deletedAt: Date?) -> Date? {
        deletedAt?.addingTimeInterval(recoveryWindow)
    }

    private static func key<T: SoftDeletableRecord>(for item: T) -> String {
        "\(String(describing: T.self)):\(item.id.uuidString)"
    }

    private static func loadEntries(defaults: UserDefaults) -> [String: Date] {
        guard let data = defaults.data(forKey: defaultsKey),
              let entries = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }

        return entries
    }

    private static func save(_ entries: [String: Date], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}

extension ModelContext {
    var cbtStore: CBTDataStore {
        CBTDataStore(modelContext: self)
    }

    func deleteAllCBTRecords() throws {
        try SharedPersistence.deleteAllModelRecords(in: self)
    }
}
