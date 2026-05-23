import XCTest
import SwiftData
@testable import CBT

final class CBTTests: XCTestCase {
    func testAppConfigurationUsesExpectedCloudContainer() {
        XCTAssertEqual(AppConfiguration.cloudKitContainerIdentifier, "iCloud.com.melichan.CBT")
        XCTAssertEqual(AppConfiguration.appGroupIdentifier, "group.com.melichan.CBT")
    }

    @MainActor
    func testDataExportIncludesDailyPlanAndGuidedJournalModels() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        context.insert(ProgramProgress(programID: "test_program", completedDays: 2))
        context.insert(FlexibleJournalEntry(templateType: "gratitude", responses: ["One", "Two"]))
        context.insert(MoodCheckIn(moodScore: 7, notes: "Settled"))
        context.insert(BreathingSession(durationSeconds: 180))
        context.insert(SafetyPlan(personalWarningSigns: ["Withdrawing"]))
        try context.save()

        let payload = try DataExportService().makePayload(from: context)

        XCTAssertEqual(payload.programProgresses?.count, 1)
        XCTAssertEqual(payload.flexibleJournalEntries?.count, 1)
        XCTAssertEqual(payload.moodCheckIns?.count, 1)
        XCTAssertEqual(payload.breathingSessions?.count, 1)
        XCTAssertEqual(payload.safetyPlans?.count, 1)
    }

    @MainActor
    func testClinicalReportAggregatesRecentProgress() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        context.insert(MoodEntry(createdAt: calendar.date(byAdding: .day, value: -80, to: now)!, moodScore: 4, intensity: 70))
        context.insert(MoodEntry(createdAt: calendar.date(byAdding: .day, value: -20, to: now)!, moodScore: 8, intensity: 30))
        context.insert(ThoughtRecord(createdAt: calendar.date(byAdding: .day, value: -10, to: now)!, distortions: ["Catastrophizing", "Mind Reading"], intensityBefore: 80, intensityAfter: 35))
        context.insert(ThoughtRecord(createdAt: calendar.date(byAdding: .day, value: -5, to: now)!, distortions: ["Catastrophizing"], intensityBefore: 60, intensityAfter: 30))
        context.insert(AssessmentLog(date: calendar.date(byAdding: .day, value: -70, to: now)!, assessmentType: "PHQ-9", score: 12))
        context.insert(AssessmentLog(date: calendar.date(byAdding: .day, value: -2, to: now)!, assessmentType: "PHQ-9", score: 7))
        try context.save()

        let report = try ClinicalReportGenerator(calendar: calendar).generateReport(from: context)

        XCTAssertEqual(report.windows.count, 3)
        XCTAssertEqual(report.windows.first(where: { $0.days == 30 })?.moodEntryCount, 1)
        XCTAssertEqual(report.windows.first(where: { $0.days == 90 })?.moodEntryCount, 2)
        XCTAssertEqual(report.distortionFrequencies.first?.label, "Catastrophizing")
        XCTAssertEqual(report.distortionFrequencies.first?.count, 2)
        XCTAssertEqual(report.assessmentSummaries.first?.assessmentType, "PHQ-9")
        XCTAssertEqual(report.assessmentSummaries.first?.change, -5)
        XCTAssertEqual(report.moodTrend.lowestScore, 4)
        XCTAssertEqual(report.moodTrend.highestScore, 8)
    }
}
