import SwiftData
import XCTest
@testable import CBT

@MainActor
final class CoreFlowBehaviorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testDailyCheckInSaveThenUpdateKeepsOneEntryForTheDay() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = container.mainContext
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 9)))
        let afternoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 16)))

        try upsertDailyCheckIn(
            in: context,
            createdAt: morning,
            moodScore: 4,
            stressScore: 7,
            energyScore: 3,
            sleepQualityScore: 2,
            triggers: ["Work"],
            notes: "Tense morning",
            helpedToday: "Walked outside"
        )
        try upsertDailyCheckIn(
            in: context,
            createdAt: afternoon,
            moodScore: 7,
            stressScore: 3,
            energyScore: 6,
            sleepQualityScore: 4,
            triggers: ["Plans"],
            notes: "Better after lunch",
            helpedToday: "Asked for help"
        )

        let moodEntries = try context.fetch(FetchDescriptor<MoodEntry>())
        let moodCheckIns = try context.fetch(FetchDescriptor<MoodCheckIn>())

        XCTAssertEqual(moodEntries.count, 1)
        XCTAssertEqual(moodEntries.first?.createdAt, morning)
        XCTAssertEqual(moodEntries.first?.moodScore, 7)
        XCTAssertEqual(moodEntries.first?.anxietyStressScore, 3)
        XCTAssertEqual(moodEntries.first?.energyScore, 6)
        XCTAssertEqual(moodEntries.first?.sleepQualityScore, 4)
        XCTAssertEqual(moodEntries.first?.triggers, ["Plans"])
        XCTAssertEqual(moodEntries.first?.notes, "Better after lunch")
        XCTAssertEqual(moodEntries.first?.helpedToday, "Asked for help")

        XCTAssertEqual(moodCheckIns.count, 1)
        XCTAssertEqual(moodCheckIns.first?.createdAt, morning)
        XCTAssertEqual(moodCheckIns.first?.moodScore, 7)
        XCTAssertEqual(moodCheckIns.first?.notes, "Better after lunch")
    }

    func testUsageGateCurrentlyAllowsCreationEvenPastTrialLimit() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = container.mainContext
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))

        for offset in 0...(UsageGate.trialLimit + 2) {
            let date = try XCTUnwrap(calendar.date(byAdding: .minute, value: offset, to: start))
            context.insert(MoodCheckIn(createdAt: date, moodScore: 5))
        }
        try context.save()

        XCTAssertTrue(UsageGate.canCreateNewItem(in: context))
    }

    func testSafetyPlanSurvivesExportImportAndIsReadableAfterRestore() throws {
        let source = try SharedPersistence.makeInMemoryModelContainer()
        let destination = try SharedPersistence.makeInMemoryModelContainer()
        let sourceContext = source.mainContext
        let planID = UUID()
        let createdAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8)))
        let updatedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 12)))
        let plan = SafetyPlan(
            id: planID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            emergencyContacts: [
                EmergencyContact(name: "Alex", relationship: "Friend", phoneNumber: "555-0100", notes: "Can text")
            ],
            personalWarningSigns: ["Skipping meals"],
            copingStrategies: ["Cold water"],
            groundingSteps: ["Name five things"],
            safePlaces: ["Library"],
            reminders: ["This feeling passes"],
            makesItWorse: ["Scrolling"],
            privacySafeDisplayEnabled: false
        )
        sourceContext.insert(plan)
        try sourceContext.save()

        let exportURL = try DataExportService().exportDataFileURL(from: sourceContext)
        try DataImportService().importData(from: exportURL, into: destination.mainContext)

        let restoredPlans = try destination.mainContext.fetch(FetchDescriptor<SafetyPlan>())

        XCTAssertEqual(restoredPlans.count, 1)
        let restored = try XCTUnwrap(restoredPlans.first)
        XCTAssertEqual(restored.id, planID)
        XCTAssertEqual(restored.emergencyContacts.first?.name, "Alex")
        XCTAssertEqual(restored.personalWarningSigns, ["Skipping meals"])
        XCTAssertEqual(restored.copingStrategies, ["Cold water"])
        XCTAssertEqual(restored.groundingSteps, ["Name five things"])
        XCTAssertEqual(restored.safePlaces, ["Library"])
        XCTAssertEqual(restored.reminders, ["This feeling passes"])
        XCTAssertEqual(restored.makesItWorse, ["Scrolling"])
        XCTAssertFalse(restored.privacySafeDisplayEnabled)
    }

    func testImportExportRoundTripRestoresCoreRecordsAndUpdatesExistingRows() throws {
        let source = try SharedPersistence.makeInMemoryModelContainer()
        let destination = try SharedPersistence.makeInMemoryModelContainer()
        let sourceContext = source.mainContext
        let destinationContext = destination.mainContext
        let createdAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 10)))
        let moodID = UUID()
        let thoughtID = UUID()
        let completionID = UUID()

        sourceContext.insert(MoodEntry(
            id: moodID,
            createdAt: createdAt,
            moodScore: 8,
            emotions: ["Calm"],
            triggers: ["Sleep"],
            sensations: ["Warm"],
            contextTags: ["Home"],
            activityTags: ["Walk"],
            notes: "Source mood",
            intensity: 4
        ))
        sourceContext.insert(ThoughtRecord(
            id: thoughtID,
            createdAt: createdAt,
            situation: "A meeting changed",
            automaticThought: "I messed up",
            emotions: ["Anxious"],
            distortions: ["Catastrophizing"],
            evidenceFor: "It was abrupt",
            evidenceAgainst: "No one blamed me",
            balancedThought: "Plans changed, and I can adapt.",
            intensityBefore: 80,
            intensityAfter: 35
        ))
        sourceContext.insert(ExerciseCompletion(
            id: completionID,
            createdAt: createdAt,
            exerciseID: "grounding",
            notes: "Useful",
            adaptiveMode: DailyPlanMode.lowEnergy.rawValue
        ))
        try sourceContext.save()

        destinationContext.insert(MoodEntry(id: moodID, createdAt: createdAt, moodScore: 1, isDeleted: true))
        try destinationContext.save()

        let exportURL = try DataExportService().exportDataFileURL(from: sourceContext)
        try DataImportService().importData(from: exportURL, into: destinationContext)

        let moods = try destinationContext.fetch(FetchDescriptor<MoodEntry>())
        let thoughts = try destinationContext.fetch(FetchDescriptor<ThoughtRecord>())
        let completions = try destinationContext.fetch(FetchDescriptor<ExerciseCompletion>())

        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(moods.first?.id, moodID)
        XCTAssertEqual(moods.first?.moodScore, 8)
        XCTAssertEqual(moods.first?.emotions, ["Calm"])
        XCTAssertEqual(moods.first?.triggers, ["Sleep"])
        XCTAssertFalse(moods.first?.isDeleted ?? true)

        XCTAssertEqual(thoughts.count, 1)
        XCTAssertEqual(thoughts.first?.id, thoughtID)
        XCTAssertEqual(thoughts.first?.balancedThought, "Plans changed, and I can adapt.")
        XCTAssertFalse(thoughts.first?.isDraft ?? true)

        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.id, completionID)
        XCTAssertEqual(completions.first?.exerciseID, "grounding")
        XCTAssertEqual(completions.first?.adaptiveMode, DailyPlanMode.lowEnergy.rawValue)
    }

    func testContinueWhereYouLeftOffPrefersRecentUnfinishedWorkAndFallsBackToDailyPlan() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = container.mainContext
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 12)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let oldDate = try XCTUnwrap(calendar.date(byAdding: .day, value: -20, to: now))

        context.insert(ThoughtRecord(
            createdAt: oldDate,
            situation: "Old draft",
            intensityBefore: 70,
            intensityAfter: 60,
            updatedAt: oldDate,
            isDraft: true
        ))
        context.insert(ThoughtRecord(
            createdAt: yesterday,
            situation: "Recent draft",
            intensityBefore: 80,
            intensityAfter: 50,
            updatedAt: yesterday,
            isDraft: true
        ))
        try context.save()

        let best = ContinueItemService.shared.bestItem(
            from: context,
            recommendations: [Self.dailyRecommendation(title: "Daily Check-In", priority: 80)],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(best?.title, "Finish Thought Record")
        XCTAssertEqual(best?.subtitle, "Recent draft")

        let emptyContainer = try SharedPersistence.makeInMemoryModelContainer()
        let fallback = ContinueItemService.shared.bestItem(
            from: emptyContainer.mainContext,
            recommendations: [Self.dailyRecommendation(title: "Daily Check-In", priority: 80)],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(fallback?.title, "Daily Check-In")
        XCTAssertEqual(fallback?.destination, .dailyPlan(.moodCheckIn))
    }

    private func upsertDailyCheckIn(
        in context: ModelContext,
        createdAt: Date,
        moodScore: Int,
        stressScore: Int,
        energyScore: Int,
        sleepQualityScore: Int,
        triggers: [String],
        notes: String?,
        helpedToday: String?
    ) throws {
        let start = calendar.startOfDay(for: createdAt)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        var moodDescriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> {
                $0.isDeleted == false &&
                $0.createdAt >= start &&
                $0.createdAt < end
            },
            sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
        )
        moodDescriptor.fetchLimit = 1

        let entry = try context.fetch(moodDescriptor).first ?? MoodEntry(createdAt: createdAt, moodScore: moodScore)
        if entry.modelContext == nil {
            context.insert(entry)
        }
        entry.moodScore = MoodEntry.clampMoodScore(moodScore)
        entry.intensity = stressScore
        entry.anxietyStressScore = stressScore
        entry.energyScore = energyScore
        entry.sleepQualityScore = sleepQualityScore
        entry.triggers = triggers
        entry.notes = notes
        entry.helpedToday = helpedToday

        var checkInDescriptor = FetchDescriptor<MoodCheckIn>(
            predicate: #Predicate<MoodCheckIn> {
                $0.isDeleted == false &&
                $0.createdAt >= start &&
                $0.createdAt < end
            },
            sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
        )
        checkInDescriptor.fetchLimit = 1

        if let checkIn = try context.fetch(checkInDescriptor).first {
            checkIn.moodScore = moodScore
            checkIn.notes = notes
        } else {
            context.insert(MoodCheckIn(createdAt: entry.createdAt, moodScore: moodScore, notes: notes))
        }

        try DailyPlanCompletionService.shared.complete(
            itemType: .moodCheckIn,
            title: "Mood check-in",
            on: entry.createdAt,
            in: context,
            calendar: calendar
        )
        try context.save()
    }

    private static func dailyRecommendation(title: String, priority: Int) -> DailyRecommendation {
        DailyRecommendation(
            id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            type: .moodCheckIn,
            title: title,
            subtitle: "A short step.",
            reason: "Because this step is still open.",
            destination: .moodCheckIn,
            priority: priority,
            estimatedDurationMinutes: 1,
            isCompletedToday: false,
            mode: .full
        )
    }
}
