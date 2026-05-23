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
        var existingPlannedActivitiesByID = try fetchExistingPlannedActivities(in: modelContext)
        var existingAssessmentLogsByID = try fetchExistingAssessmentLogs(in: modelContext)
        var existingPersonalityAssessmentLogsByID = try fetchExistingPersonalityAssessmentLogs(in: modelContext)
        var existingProgramProgressesByID = try fetchExistingProgramProgresses(in: modelContext)
        var existingFlexibleJournalEntriesByID = try fetchExistingFlexibleJournalEntries(in: modelContext)
        var existingMoodCheckInsByID = try fetchExistingMoodCheckIns(in: modelContext)
        var existingBreathingSessionsByID = try fetchExistingBreathingSessions(in: modelContext)
        var existingSafetyPlansByID = try fetchExistingSafetyPlans(in: modelContext)

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

        if let plannedActivities = payload.plannedActivities {
            for activity in plannedActivities {
                if let existingActivity = existingPlannedActivitiesByID[activity.id] {
                    update(existingActivity, from: activity)
                } else {
                    let plannedActivity = PlannedActivity(
                        id: activity.id,
                        createdAt: activity.createdAt,
                        title: activity.title,
                        activityDescription: activity.activityDescription,
                        category: PlannedActivity.normalizedCategory(activity.category),
                        scheduledDate: activity.scheduledDate,
                        predictedEnjoyment: PlannedActivity.clampRating(activity.predictedEnjoyment),
                        actualEnjoyment: activity.actualEnjoyment.map(PlannedActivity.clampRating),
                        isCompleted: activity.isCompleted,
                        completedAt: activity.completedAt,
                        notes: activity.notes
                    )
                    modelContext.insert(plannedActivity)
                    existingPlannedActivitiesByID[activity.id] = plannedActivity
                }
            }
        }

        if let assessmentLogs = payload.assessmentLogs {
            for log in assessmentLogs {
                if let existingLog = existingAssessmentLogsByID[log.id] {
                    update(existingLog, from: log)
                } else {
                    let assessmentLog = AssessmentLog(
                        id: log.id,
                        date: log.date,
                        assessmentType: log.assessmentType,
                        score: log.score,
                        scoreValue: log.scoreValue
                    )
                    modelContext.insert(assessmentLog)
                    existingAssessmentLogsByID[log.id] = assessmentLog
                }
            }
        }

        if let personalityAssessmentLogs = payload.personalityAssessmentLogs {
            for log in personalityAssessmentLogs {
                if let existingLog = existingPersonalityAssessmentLogsByID[log.id] {
                    update(existingLog, from: log)
                } else {
                    let personalityLog = PersonalityAssessmentLog(
                        id: log.id,
                        date: log.date,
                        opennessScore: log.opennessScore,
                        conscientiousnessScore: log.conscientiousnessScore,
                        extraversionScore: log.extraversionScore,
                        agreeablenessScore: log.agreeablenessScore,
                        neuroticismScore: log.neuroticismScore
                    )
                    modelContext.insert(personalityLog)
                    existingPersonalityAssessmentLogsByID[log.id] = personalityLog
                }
            }
        }

        if let programProgresses = payload.programProgresses {
            for progress in programProgresses {
                if let existingProgress = existingProgramProgressesByID[progress.id] {
                    update(existingProgress, from: progress)
                } else {
                    let programProgress = ProgramProgress(
                        id: progress.id,
                        programID: progress.programID,
                        completedDays: progress.completedDays,
                        lastCompletedAt: progress.lastCompletedAt
                    )
                    modelContext.insert(programProgress)
                    existingProgramProgressesByID[progress.id] = programProgress
                }
            }
        }

        if let flexibleJournalEntries = payload.flexibleJournalEntries {
            for entry in flexibleJournalEntries {
                if let existingEntry = existingFlexibleJournalEntriesByID[entry.id] {
                    update(existingEntry, from: entry)
                } else {
                    let journalEntry = FlexibleJournalEntry(
                        id: entry.id,
                        date: entry.date,
                        templateType: entry.templateType,
                        responses: entry.responses
                    )
                    modelContext.insert(journalEntry)
                    existingFlexibleJournalEntriesByID[entry.id] = journalEntry
                }
            }
        }

        if let moodCheckIns = payload.moodCheckIns {
            for checkIn in moodCheckIns {
                if let existingCheckIn = existingMoodCheckInsByID[checkIn.id] {
                    update(existingCheckIn, from: checkIn)
                } else {
                    let moodCheckIn = MoodCheckIn(
                        id: checkIn.id,
                        createdAt: checkIn.createdAt,
                        moodScore: checkIn.moodScore,
                        notes: checkIn.notes
                    )
                    modelContext.insert(moodCheckIn)
                    existingMoodCheckInsByID[checkIn.id] = moodCheckIn
                }
            }
        }

        if let breathingSessions = payload.breathingSessions {
            for session in breathingSessions {
                if let existingSession = existingBreathingSessionsByID[session.id] {
                    update(existingSession, from: session)
                } else {
                    let breathingSession = BreathingSession(
                        id: session.id,
                        createdAt: session.createdAt,
                        durationSeconds: session.durationSeconds
                    )
                    modelContext.insert(breathingSession)
                    existingBreathingSessionsByID[session.id] = breathingSession
                }
            }
        }

        if let safetyPlans = payload.safetyPlans {
            for plan in safetyPlans {
                if let existingPlan = existingSafetyPlansByID[plan.id] {
                    update(existingPlan, from: plan)
                } else {
                    let safetyPlan = SafetyPlan(
                        id: plan.id,
                        createdAt: plan.createdAt,
                        updatedAt: plan.updatedAt,
                        emergencyContacts: plan.emergencyContacts,
                        personalWarningSigns: plan.personalWarningSigns,
                        copingStrategies: plan.copingStrategies
                    )
                    modelContext.insert(safetyPlan)
                    existingSafetyPlansByID[plan.id] = safetyPlan
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

    private func fetchExistingPlannedActivities(in modelContext: ModelContext) throws -> [UUID: PlannedActivity] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<PlannedActivity>()))
    }

    private func fetchExistingAssessmentLogs(in modelContext: ModelContext) throws -> [UUID: AssessmentLog] {
        Dictionary(
            try modelContext.fetch(FetchDescriptor<AssessmentLog>()).map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    private func fetchExistingPersonalityAssessmentLogs(in modelContext: ModelContext) throws -> [UUID: PersonalityAssessmentLog] {
        Dictionary(
            try modelContext.fetch(FetchDescriptor<PersonalityAssessmentLog>()).map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    private func fetchExistingProgramProgresses(in modelContext: ModelContext) throws -> [UUID: ProgramProgress] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<ProgramProgress>()))
    }

    private func fetchExistingFlexibleJournalEntries(in modelContext: ModelContext) throws -> [UUID: FlexibleJournalEntry] {
        Dictionary(
            try modelContext.fetch(FetchDescriptor<FlexibleJournalEntry>()).map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    private func fetchExistingMoodCheckIns(in modelContext: ModelContext) throws -> [UUID: MoodCheckIn] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<MoodCheckIn>()))
    }

    private func fetchExistingBreathingSessions(in modelContext: ModelContext) throws -> [UUID: BreathingSession] {
        try existingRecordsByID(from: modelContext.fetch(FetchDescriptor<BreathingSession>()))
    }

    private func fetchExistingSafetyPlans(in modelContext: ModelContext) throws -> [UUID: SafetyPlan] {
        Dictionary(
            try modelContext.fetch(FetchDescriptor<SafetyPlan>()).map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
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

    private func update(_ activity: PlannedActivity, from export: PlannedActivityExport) {
        activity.createdAt = export.createdAt
        activity.title = export.title
        activity.activityDescription = export.activityDescription
        activity.category = PlannedActivity.normalizedCategory(export.category)
        activity.scheduledDate = export.scheduledDate
        activity.predictedEnjoyment = PlannedActivity.clampRating(export.predictedEnjoyment)
        activity.actualEnjoyment = export.actualEnjoyment.map(PlannedActivity.clampRating)
        activity.isCompleted = export.isCompleted
        activity.completedAt = export.completedAt
        activity.notes = export.notes
        activity.isDeleted = false
    }

    private func update(_ log: AssessmentLog, from export: AssessmentLogExport) {
        log.date = export.date
        log.assessmentType = export.assessmentType
        log.score = export.score
        log.scoreValue = export.scoreValue
    }

    private func update(_ log: PersonalityAssessmentLog, from export: PersonalityAssessmentLogExport) {
        log.date = export.date
        log.opennessScore = export.opennessScore
        log.conscientiousnessScore = export.conscientiousnessScore
        log.extraversionScore = export.extraversionScore
        log.agreeablenessScore = export.agreeablenessScore
        log.neuroticismScore = export.neuroticismScore
    }

    private func update(_ progress: ProgramProgress, from export: ProgramProgressExport) {
        progress.programID = export.programID
        progress.completedDays = max(0, export.completedDays)
        progress.lastCompletedAt = export.lastCompletedAt
        progress.isDeleted = false
    }

    private func update(_ entry: FlexibleJournalEntry, from export: FlexibleJournalEntryExport) {
        entry.date = export.date
        entry.templateType = export.templateType
        entry.responses = export.responses
    }

    private func update(_ checkIn: MoodCheckIn, from export: MoodCheckInExport) {
        checkIn.createdAt = export.createdAt
        checkIn.moodScore = min(10, max(1, export.moodScore))
        checkIn.notes = export.notes
        checkIn.isDeleted = false
    }

    private func update(_ session: BreathingSession, from export: BreathingSessionExport) {
        session.createdAt = export.createdAt
        session.durationSeconds = max(0, export.durationSeconds)
        session.isDeleted = false
    }

    private func update(_ plan: SafetyPlan, from export: SafetyPlanExport) {
        plan.createdAt = export.createdAt
        plan.emergencyContacts = export.emergencyContacts
        plan.personalWarningSigns = export.personalWarningSigns
        plan.copingStrategies = export.copingStrategies
        plan.updatedAt = export.updatedAt
    }
}
