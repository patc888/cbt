import Foundation
import SwiftData

nonisolated struct MoodEntryExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let moodScore: Int
    let emotions: [String]
    let triggers: [String]?
    let notes: String?
    let intensity: Int?
}

nonisolated struct ThoughtRecordExport: Codable, Sendable {
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

nonisolated struct ExerciseCompletionExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let exerciseID: String
    let notes: String?
}

nonisolated struct JournalEntryExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let title: String
    let body: String
    let sourceKind: String?
    let sourceID: String?
    let durationSeconds: Int?
}

nonisolated struct PlannedActivityExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let title: String
    let activityDescription: String
    let category: String
    let scheduledDate: Date
    let predictedEnjoyment: Int
    let actualEnjoyment: Int?
    let isCompleted: Bool
    let completedAt: Date?
    let notes: String?
}

nonisolated struct AssessmentLogExport: Codable, Sendable {
    let id: UUID
    let date: Date
    let assessmentType: String
    let score: Int
    let scoreValue: Double?
}

nonisolated struct PersonalityAssessmentLogExport: Codable, Sendable {
    let id: UUID
    let date: Date
    let opennessScore: Double
    let conscientiousnessScore: Double
    let extraversionScore: Double
    let agreeablenessScore: Double
    let neuroticismScore: Double
}

nonisolated struct ProgramProgressExport: Codable, Sendable {
    let id: UUID
    let programID: String
    let completedDays: Int
    let lastCompletedAt: Date?
}

nonisolated struct FlexibleJournalEntryExport: Codable, Sendable {
    let id: UUID
    let date: Date
    let templateType: String
    let responses: [String]
}

nonisolated struct MoodCheckInExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let moodScore: Int
    let notes: String?
}

nonisolated struct BreathingSessionExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let durationSeconds: Int
}

nonisolated struct SafetyPlanExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let emergencyContacts: [EmergencyContact]
    let personalWarningSigns: [String]
    let copingStrategies: [String]
}

nonisolated struct CBTDataExportPayload: Codable, Sendable {
    let exportedAt: String
    let appVersion: String?
    let moodEntries: [MoodEntryExport]
    let thoughtRecords: [ThoughtRecordExport]
    let exerciseCompletions: [ExerciseCompletionExport]
    let journalEntries: [JournalEntryExport]?
    let plannedActivities: [PlannedActivityExport]?
    let assessmentLogs: [AssessmentLogExport]?
    let personalityAssessmentLogs: [PersonalityAssessmentLogExport]?
    let programProgresses: [ProgramProgressExport]?
    let flexibleJournalEntries: [FlexibleJournalEntryExport]?
    let moodCheckIns: [MoodCheckInExport]?
    let breathingSessions: [BreathingSessionExport]?
    let safetyPlans: [SafetyPlanExport]?
}

struct DataExportService {
    @MainActor
    func exportDataFileURL(from container: ModelContainer) async throws -> URL {
        let modelContext = ModelContext(container)
        return try exportDataFileURL(from: modelContext)
    }

    @MainActor
    func exportDataFileURL(from modelContext: ModelContext) throws -> URL {
        let payload = try makePayload(from: modelContext)

        let data = try makeEncodedData(from: payload)
        let filenameDate = Self.makeFilenameDateString()
        let filename = "CBT-Export-\(filenameDate)-\(UUID().uuidString).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    @MainActor
    func makePayload(from modelContext: ModelContext) throws -> CBTDataExportPayload {
        let moodDescriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\MoodEntry.createdAt)]
        )
        let thoughtDescriptor = FetchDescriptor<ThoughtRecord>(
            predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\ThoughtRecord.createdAt)]
        )
        let completionDescriptor = FetchDescriptor<ExerciseCompletion>(
            predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\ExerciseCompletion.createdAt)]
        )
        let journalDescriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\JournalEntry.createdAt)]
        )
        let plannedActivityDescriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate<PlannedActivity> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\PlannedActivity.scheduledDate)]
        )
        let assessmentDescriptor = FetchDescriptor<AssessmentLog>(
            sortBy: [SortDescriptor(\AssessmentLog.date)]
        )
        let personalityAssessmentDescriptor = FetchDescriptor<PersonalityAssessmentLog>(
            sortBy: [SortDescriptor(\PersonalityAssessmentLog.date)]
        )
        let programProgressDescriptor = FetchDescriptor<ProgramProgress>(
            predicate: #Predicate<ProgramProgress> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\ProgramProgress.programID)]
        )
        let flexibleJournalDescriptor = FetchDescriptor<FlexibleJournalEntry>(
            sortBy: [SortDescriptor(\FlexibleJournalEntry.date)]
        )
        let moodCheckInDescriptor = FetchDescriptor<MoodCheckIn>(
            predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\MoodCheckIn.createdAt)]
        )
        let breathingSessionDescriptor = FetchDescriptor<BreathingSession>(
            predicate: #Predicate<BreathingSession> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\BreathingSession.createdAt)]
        )
        let safetyPlanDescriptor = FetchDescriptor<SafetyPlan>(
            sortBy: [SortDescriptor(\SafetyPlan.updatedAt, order: .reverse)]
        )

        let moodEntries = try modelContext.fetch(moodDescriptor).map {
            MoodEntryExport(
                id: $0.id,
                createdAt: $0.createdAt,
                moodScore: $0.moodScore,
                emotions: $0.emotions,
                triggers: $0.triggers,
                notes: $0.notes,
                intensity: $0.intensity
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

        let journalEntries = try modelContext.fetch(journalDescriptor).map {
            JournalEntryExport(
                id: $0.id,
                createdAt: $0.createdAt,
                title: $0.title,
                body: $0.body,
                sourceKind: $0.sourceKind,
                sourceID: $0.sourceID,
                durationSeconds: $0.durationSeconds
            )
        }

        let plannedActivities = try modelContext.fetch(plannedActivityDescriptor).map {
            PlannedActivityExport(
                id: $0.id,
                createdAt: $0.createdAt,
                title: $0.title,
                activityDescription: $0.activityDescription,
                category: $0.category,
                scheduledDate: $0.scheduledDate,
                predictedEnjoyment: PlannedActivity.clampRating($0.predictedEnjoyment),
                actualEnjoyment: $0.actualEnjoyment.map(PlannedActivity.clampRating),
                isCompleted: $0.isCompleted,
                completedAt: $0.completedAt,
                notes: $0.notes
            )
        }

        let assessmentLogs = try modelContext.fetch(assessmentDescriptor).map {
            AssessmentLogExport(
                id: $0.id,
                date: $0.date,
                assessmentType: $0.assessmentType,
                score: $0.score,
                scoreValue: $0.scoreValue
            )
        }

        let personalityAssessmentLogs = try modelContext.fetch(personalityAssessmentDescriptor).map {
            PersonalityAssessmentLogExport(
                id: $0.id,
                date: $0.date,
                opennessScore: $0.opennessScore,
                conscientiousnessScore: $0.conscientiousnessScore,
                extraversionScore: $0.extraversionScore,
                agreeablenessScore: $0.agreeablenessScore,
                neuroticismScore: $0.neuroticismScore
            )
        }

        let programProgresses = try modelContext.fetch(programProgressDescriptor).map {
            ProgramProgressExport(
                id: $0.id,
                programID: $0.programID,
                completedDays: $0.completedDays,
                lastCompletedAt: $0.lastCompletedAt
            )
        }

        let flexibleJournalEntries = try modelContext.fetch(flexibleJournalDescriptor).map {
            FlexibleJournalEntryExport(
                id: $0.id,
                date: $0.date,
                templateType: $0.templateType,
                responses: $0.responses
            )
        }

        let moodCheckIns = try modelContext.fetch(moodCheckInDescriptor).map {
            MoodCheckInExport(
                id: $0.id,
                createdAt: $0.createdAt,
                moodScore: $0.moodScore,
                notes: $0.notes
            )
        }

        let breathingSessions = try modelContext.fetch(breathingSessionDescriptor).map {
            BreathingSessionExport(
                id: $0.id,
                createdAt: $0.createdAt,
                durationSeconds: $0.durationSeconds
            )
        }

        let safetyPlans = try modelContext.fetch(safetyPlanDescriptor).map {
            SafetyPlanExport(
                id: $0.id,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                emergencyContacts: $0.emergencyContacts,
                personalWarningSigns: $0.personalWarningSigns,
                copingStrategies: $0.copingStrategies
            )
        }

        return CBTDataExportPayload(
            exportedAt: Self.makeExportDateString(),
            appVersion: Self.appVersion,
            moodEntries: moodEntries,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            plannedActivities: plannedActivities,
            assessmentLogs: assessmentLogs,
            personalityAssessmentLogs: personalityAssessmentLogs,
            programProgresses: programProgresses,
            flexibleJournalEntries: flexibleJournalEntries,
            moodCheckIns: moodCheckIns,
            breathingSessions: breathingSessions,
            safetyPlans: safetyPlans
        )
    }

    @MainActor
    private func makeEncodedData(from payload: CBTDataExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    private nonisolated static func makeExportDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private nonisolated static func makeFilenameDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: Date())
    }

    private nonisolated static var appVersion: String? {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let shortVersion, let build, !build.isEmpty {
            return "\(shortVersion) (\(build))"
        }

        return shortVersion
    }
}
