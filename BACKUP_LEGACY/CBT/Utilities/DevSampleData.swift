import Foundation
import SwiftData

#if DEBUG
enum DevSampleData {
    static func seedIfNeeded(in modelContext: ModelContext) throws {
        let moodCount = try modelContext.fetchCount(FetchDescriptor<MoodEntry>())
        guard moodCount == 0 else { return }

        let store = CBTDataStore(modelContext: modelContext)
        try store.insertMoodEntry(
            moodScore: 6,
            emotions: ["anxious", "tired"],
            notes: "Workday stress, took a short walk."
        )
        try store.insertMoodEntry(
            moodScore: 8,
            emotions: ["calm", "hopeful"],
            notes: "Good conversation and evening routine."
        )

        try store.insertThoughtRecord(
            situation: "Had to present in a meeting.",
            automaticThought: "I will mess this up.",
            emotions: ["nervous", "self-doubt"],
            distortions: ["catastrophizing"],
            evidenceFor: "I felt shaky before starting.",
            evidenceAgainst: "I prepared and got positive feedback.",
            balancedThought: "I can feel anxious and still do this well.",
            intensityBefore: 75,
            intensityAfter: 35
        )

        try store.insertExerciseCompletion(
            exerciseID: "breathing_box_v1",
            notes: "Completed before bed."
        )
    }
}
#endif
