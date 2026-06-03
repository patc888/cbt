import XCTest
@testable import CBT

final class CopingToolkitStoreTests: XCTestCase {
    func testFavoriteToggleAddsAndRemovesToolIDs() throws {
        let defaults = try makeDefaults()
        let store = CopingToolkitStore(defaults: defaults)

        XCTAssertFalse(store.isFavorite("toolkit_breathing_60"))

        XCTAssertTrue(store.toggleFavorite("toolkit_breathing_60"))
        XCTAssertTrue(store.isFavorite("toolkit_breathing_60"))
        XCTAssertEqual(store.favoriteIDs, ["toolkit_breathing_60"])

        XCTAssertFalse(store.toggleFavorite("toolkit_breathing_60"))
        XCTAssertFalse(store.isFavorite("toolkit_breathing_60"))
        XCTAssertTrue(store.favoriteIDs.isEmpty)
    }

    func testUsageTrackingKeepsMostRecentUsePerTool() throws {
        let defaults = try makeDefaults()
        let store = CopingToolkitStore(defaults: defaults)
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)
        let third = Date(timeIntervalSince1970: 300)

        store.recordUsage("exercise_act_003", at: first)
        store.recordUsage("exercise_mindfulness_003", at: second)
        store.recordUsage("exercise_act_003", at: third)

        XCTAssertEqual(store.recentToolIDs(limit: 3), [
            "exercise_act_003",
            "exercise_mindfulness_003"
        ])
        XCTAssertEqual(store.usage.first?.usedAt, third)
    }

    func testCopingPlanToggleAddsAndRemovesToolIDs() throws {
        let defaults = try makeDefaults()
        let store = CopingToolkitStore(defaults: defaults)

        XCTAssertFalse(store.isInCopingPlan("toolkit_breathing_60"))

        XCTAssertTrue(store.toggleCopingPlanTool("toolkit_breathing_60"))
        XCTAssertTrue(store.isInCopingPlan("toolkit_breathing_60"))
        XCTAssertEqual(store.copingPlanToolIDs, ["toolkit_breathing_60"])

        XCTAssertTrue(store.toggleCopingPlanTool("exercise_mindfulness_003"))
        XCTAssertEqual(store.copingPlanToolIDs, [
            "exercise_mindfulness_003",
            "toolkit_breathing_60"
        ])

        XCTAssertFalse(store.toggleCopingPlanTool("toolkit_breathing_60"))
        XCTAssertFalse(store.isInCopingPlan("toolkit_breathing_60"))
        XCTAssertEqual(store.copingPlanToolIDs, ["exercise_mindfulness_003"])
    }

    func testCopingPlanKeepsEmergencyKitToFiveTools() throws {
        let defaults = try makeDefaults()
        let store = CopingToolkitStore(defaults: defaults)

        for id in ["one", "two", "three", "four", "five"] {
            XCTAssertTrue(store.toggleCopingPlanTool(id))
        }

        XCTAssertFalse(store.canAddCopingPlanTool("six"))
        XCTAssertFalse(store.toggleCopingPlanTool("six"))
        XCTAssertEqual(store.copingPlanToolIDs, ["five", "four", "three", "two", "one"])

        XCTAssertFalse(store.toggleCopingPlanTool("three"))
        XCTAssertTrue(store.canAddCopingPlanTool("six"))
        XCTAssertTrue(store.toggleCopingPlanTool("six"))
        XCTAssertEqual(store.copingPlanToolIDs, ["six", "five", "four", "two", "one"])
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "CopingToolkitStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
