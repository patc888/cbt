import Foundation
import SwiftData

@Model
final class MoodEntry: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var moodScore: Int = 5
    var emotionsStorage: String = ""
    var notes: String?
    var isDeleted: Bool = false
    
    // Check-in V2 fields
    var intensity: Int?
    var triggersStorage: String?
    var sensationsStorage: String?
    var contextTagsStorage: String?
    var activityTagsStorage: String?
    var anxietyStressScore: Int?
    var energyScore: Int?
    var sleepQualityScore: Int?
    var helpedToday: String?

    var emotions: [String] {
        get { StringArrayStorage.decode(emotionsStorage) }
        set { emotionsStorage = StringArrayStorage.encode(newValue) }
    }
    
    var triggers: [String] {
        get {
            if let triggersStorage = triggersStorage {
                return StringArrayStorage.decode(triggersStorage)
            }
            return []
        }
        set { triggersStorage = StringArrayStorage.encode(newValue) }
    }

    var sensations: [String] {
        get {
            if let sensationsStorage = sensationsStorage {
                return StringArrayStorage.decode(sensationsStorage)
            }
            return []
        }
        set { sensationsStorage = StringArrayStorage.encode(newValue) }
    }

    var contextTags: [String] {
        get {
            if let contextTagsStorage = contextTagsStorage {
                return StringArrayStorage.decode(contextTagsStorage)
            }
            return []
        }
        set { contextTagsStorage = StringArrayStorage.encode(newValue) }
    }

    var activityTags: [String] {
        get {
            if let activityTagsStorage = activityTagsStorage {
                return StringArrayStorage.decode(activityTagsStorage)
            }
            return []
        }
        set { activityTagsStorage = StringArrayStorage.encode(newValue) }
    }

    init(
        id: UUID = UUID(),
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
        helpedToday: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.moodScore = Self.clampMoodScore(moodScore)
        self.emotionsStorage = StringArrayStorage.encode(emotions)
        self.triggersStorage = StringArrayStorage.encode(triggers)
        self.sensationsStorage = StringArrayStorage.encode(sensations)
        self.contextTagsStorage = StringArrayStorage.encode(contextTags)
        self.activityTagsStorage = StringArrayStorage.encode(activityTags)
        self.notes = notes
        self.intensity = intensity
        self.anxietyStressScore = anxietyStressScore.map(Self.clampMoodScore)
        self.energyScore = energyScore.map(Self.clampMoodScore)
        self.sleepQualityScore = sleepQualityScore.map(Self.clampMoodScore)
        self.helpedToday = helpedToday
        self.isDeleted = isDeleted
    }

    static func clampMoodScore(_ value: Int) -> Int {
        min(10, max(1, value))
    }
}
