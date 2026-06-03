import Foundation
import SwiftData

nonisolated struct MoodEntryExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let moodScore: Int
    let emotions: [String]
    let triggers: [String]?
    let sensations: [String]?
    let contextTags: [String]?
    let activityTags: [String]?
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
    let isSavedReframe: Bool?
    let isFavoriteReframe: Bool?
    let savedReframeAt: Date?
    let lastReviewedAt: Date?
    let updatedAt: Date?
    let completedAt: Date?
    let isDraft: Bool?
    let modeRawValue: String?
}

nonisolated struct ExerciseCompletionExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let exerciseID: String
    let notes: String?
    let adaptiveMode: String?
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
    let supportedValue: String?
    let predictedEnjoyment: Int
    let actualEnjoyment: Int?
    let isCompleted: Bool
    let completedAt: Date?
    let adaptiveMode: String?
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

nonisolated struct TinyWinCompletionExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let winID: String
}

nonisolated struct SafetyPlanExport: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let emergencyContacts: [EmergencyContact]
    let personalWarningSigns: [String]
    let copingStrategies: [String]
    let groundingSteps: [String]?
    let safePlaces: [String]?
    let reminders: [String]?
    let makesItWorse: [String]?
    let privacySafeDisplayEnabled: Bool?
}

nonisolated struct UserSettingsExport: Codable, Sendable {
    let singletonID: String
    let uuid: UUID?
    let hapticsEnabled: Bool?
    let currentIcon: String?
    let appLockEnabled: Bool?
    let isPremium: Bool?
}

nonisolated struct CourseExport: Codable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let descriptionText: String
    let approach: String
    let category: String
    let difficulty: String
    let approaches: [String]
    let topics: [String]
    let format: String
    let estimatedTotalDuration: Int
    let lessonCount: Int
    let lessons: [CourseLesson]
    let linkedExerciseIDs: [String]
    let linkedGuidedJournalIDs: [String]
    let finalReflectionPrompt: String?
    let completionMessage: String?
    let finalReflectionResponse: String?
    let isPremium: Bool
    let itemIDs: [String]
    let completedItemIDs: [String]
    let isCompleted: Bool
    let completedAt: Date?
}

nonisolated struct AudioContentExport: Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let category: String
    let duration: Int
    let type: AudioContentType
    let localAssetFilename: String
    let transcript: String
    let isPremium: Bool
    let isCompleted: Bool
    let completedAt: Date?
    let isFavorite: Bool
}

nonisolated struct AchievementExport: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let imageName: String
    let isUnlocked: Bool
    let unlockCondition: AchievementUnlockCondition
    let createdAt: Date
    let unlockedAt: Date?
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
    let tinyWinCompletions: [TinyWinCompletionExport]?
    let safetyPlans: [SafetyPlanExport]?
    let userSettings: [UserSettingsExport]?
    let courses: [CourseExport]?
    let audioContents: [AudioContentExport]?
    let achievements: [AchievementExport]?
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
        let tinyWinCompletionDescriptor = FetchDescriptor<TinyWinCompletion>(
            predicate: #Predicate<TinyWinCompletion> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\TinyWinCompletion.createdAt)]
        )
        let safetyPlanDescriptor = FetchDescriptor<SafetyPlan>(
            sortBy: [SortDescriptor(\SafetyPlan.updatedAt, order: .reverse)]
        )
        let userSettingsDescriptor = FetchDescriptor<UserSettings>(
            sortBy: [SortDescriptor(\UserSettings.singletonID)]
        )
        let courseDescriptor = FetchDescriptor<Course>(
            sortBy: [SortDescriptor(\Course.title)]
        )
        let audioContentDescriptor = FetchDescriptor<AudioContent>(
            sortBy: [SortDescriptor(\AudioContent.title)]
        )
        let achievementDescriptor = FetchDescriptor<Achievement>(
            sortBy: [SortDescriptor(\Achievement.createdAt)]
        )

        let moodEntries = try modelContext.fetch(moodDescriptor).map {
            MoodEntryExport(
                id: $0.id,
                createdAt: $0.createdAt,
                moodScore: $0.moodScore,
                emotions: $0.emotions,
                triggers: $0.triggers,
                sensations: $0.sensations,
                contextTags: $0.contextTags,
                activityTags: $0.activityTags,
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
                intensityAfter: $0.intensityAfter,
                isSavedReframe: $0.isSavedReframe,
                isFavoriteReframe: $0.isFavoriteReframe,
                savedReframeAt: $0.savedReframeAt,
                lastReviewedAt: $0.lastReviewedAt,
                updatedAt: $0.updatedAt,
                completedAt: $0.completedAt,
                isDraft: $0.isDraft,
                modeRawValue: $0.modeRawValue
            )
        }

        let exerciseCompletions = try modelContext.fetch(completionDescriptor).map {
            ExerciseCompletionExport(
                id: $0.id,
                createdAt: $0.createdAt,
                exerciseID: $0.exerciseID,
                notes: $0.notes,
                adaptiveMode: $0.adaptiveMode
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
                supportedValue: $0.supportedValue,
                predictedEnjoyment: PlannedActivity.clampRating($0.predictedEnjoyment),
                actualEnjoyment: $0.actualEnjoyment.map(PlannedActivity.clampRating),
                isCompleted: $0.isCompleted,
                completedAt: $0.completedAt,
                adaptiveMode: $0.adaptiveMode,
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

        let tinyWinCompletions = try modelContext.fetch(tinyWinCompletionDescriptor).map {
            TinyWinCompletionExport(
                id: $0.id,
                createdAt: $0.createdAt,
                winID: $0.winID
            )
        }

        let safetyPlans = try modelContext.fetch(safetyPlanDescriptor).map {
            SafetyPlanExport(
                id: $0.id,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                emergencyContacts: $0.emergencyContacts,
                personalWarningSigns: $0.personalWarningSigns,
                copingStrategies: $0.copingStrategies,
                groundingSteps: $0.groundingSteps,
                safePlaces: $0.safePlaces,
                reminders: $0.reminders,
                makesItWorse: $0.makesItWorse,
                privacySafeDisplayEnabled: $0.privacySafeDisplayEnabled
            )
        }

        let userSettings = try modelContext.fetch(userSettingsDescriptor).map {
            UserSettingsExport(
                singletonID: $0.singletonID,
                uuid: $0.uuid,
                hapticsEnabled: $0.hapticsEnabled,
                currentIcon: $0.currentIcon,
                appLockEnabled: $0.appLockEnabled,
                isPremium: $0.isPremium
            )
        }

        let courses = try modelContext.fetch(courseDescriptor).map {
            CourseExport(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                descriptionText: $0.descriptionText,
                approach: $0.approach,
                category: $0.category,
                difficulty: $0.difficulty,
                approaches: $0.approaches,
                topics: $0.topics,
                format: $0.format,
                estimatedTotalDuration: $0.estimatedTotalDuration,
                lessonCount: $0.lessonCount,
                lessons: $0.lessons,
                linkedExerciseIDs: $0.linkedExerciseIDs,
                linkedGuidedJournalIDs: $0.linkedGuidedJournalIDs,
                finalReflectionPrompt: $0.finalReflectionPrompt,
                completionMessage: $0.completionMessage,
                finalReflectionResponse: $0.finalReflectionResponse,
                isPremium: $0.isPremium,
                itemIDs: $0.itemIDs,
                completedItemIDs: $0.completedItemIDs,
                isCompleted: $0.isCompleted,
                completedAt: $0.completedAt
            )
        }

        let audioContents = try modelContext.fetch(audioContentDescriptor).map {
            AudioContentExport(
                id: $0.id,
                title: $0.title,
                description: $0.description,
                category: $0.category,
                duration: $0.duration,
                type: $0.type,
                localAssetFilename: $0.localAssetFilename,
                transcript: $0.transcript,
                isPremium: $0.isPremium,
                isCompleted: $0.isCompleted,
                completedAt: $0.completedAt,
                isFavorite: $0.isFavorite
            )
        }

        let achievements = try modelContext.fetch(achievementDescriptor).map {
            AchievementExport(
                id: $0.id,
                title: $0.title,
                description: $0.description,
                imageName: $0.imageName,
                isUnlocked: $0.isUnlocked,
                unlockCondition: $0.unlockCondition,
                createdAt: $0.createdAt,
                unlockedAt: $0.unlockedAt
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
            tinyWinCompletions: tinyWinCompletions,
            safetyPlans: safetyPlans,
            userSettings: userSettings,
            courses: courses,
            audioContents: audioContents,
            achievements: achievements
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
