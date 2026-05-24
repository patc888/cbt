import XCTest
@testable import CBT

final class SmartCoachTests: XCTestCase {
    func testIncludesSupportResourcesForHighDistress() {
        let record = ThoughtRecord(
            emotions: ["Overwhelmed"],
            intensityBefore: 88,
            intensityAfter: 72
        )

        XCTAssertTrue(SmartCoach.nextSteps(for: record).includesSupportResources)
    }

    func testRecommendsRelatedDistortionAndHelpfulReframe() {
        let record = ThoughtRecord(
            automaticThought: "Everything will fall apart.",
            distortions: ["Catastrophizing"],
            balancedThought: "This is hard, but I can handle one step.",
            intensityBefore: 65,
            intensityAfter: 35
        )

        let recommendations = SmartCoach.nextSteps(for: record).recommendations

        XCTAssertTrue(recommendations.contains { recommendation in
            if case .distortionLesson(let distortion) = recommendation.kind {
                return distortion == "Catastrophizing"
            }
            return false
        })
        XCTAssertTrue(recommendations.contains { $0.kind == .saveHelpfulReframe })
    }

    func testLowerDistressRecordDoesNotShowSupportResources() {
        let record = ThoughtRecord(
            emotions: ["Frustrated"],
            balancedThought: "I can revisit this calmly.",
            intensityBefore: 55,
            intensityAfter: 30
        )

        XCTAssertFalse(SmartCoach.nextSteps(for: record).includesSupportResources)
    }
}
