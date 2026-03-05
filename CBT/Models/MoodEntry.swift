import Foundation
import SwiftData

@Model
final class MoodEntry: SoftDeletableRecord {
    var id: UUID
    var createdAt: Date
    var moodScore: Int
    var emotionsStorage: String
    var notes: String?
    var isDeleted: Bool
    
    // Check-in V2 fields
    var intensity: Int?
    var triggersStorage: String?

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

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        moodScore: Int,
        emotions: [String] = [],
        triggers: [String] = [],
        notes: String? = nil,
        intensity: Int? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.moodScore = Self.clampMoodScore(moodScore)
        self.emotionsStorage = StringArrayStorage.encode(emotions)
        self.triggersStorage = StringArrayStorage.encode(triggers)
        self.notes = notes
        self.intensity = intensity
        self.isDeleted = isDeleted
    }

    static func clampMoodScore(_ value: Int) -> Int {
        min(10, max(1, value))
    }
}
