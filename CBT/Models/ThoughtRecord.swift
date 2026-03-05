import Foundation
import SwiftData

@Model
final class ThoughtRecord: SoftDeletableRecord {
    var id: UUID
    var createdAt: Date
    var situation: String
    var automaticThought: String
    var emotionsStorage: String
    var distortionsStorage: String
    var evidenceFor: String
    var evidenceAgainst: String
    var balancedThought: String
    var intensityBefore: Int
    var intensityAfter: Int
    var isDeleted: Bool

    var emotions: [String] {
        get { StringArrayStorage.decode(emotionsStorage) }
        set { emotionsStorage = StringArrayStorage.encode(newValue) }
    }

    var distortions: [String] {
        get { StringArrayStorage.decode(distortionsStorage) }
        set { distortionsStorage = StringArrayStorage.encode(newValue) }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        situation: String = "",
        automaticThought: String = "",
        emotions: [String] = [],
        distortions: [String] = [],
        evidenceFor: String = "",
        evidenceAgainst: String = "",
        balancedThought: String = "",
        intensityBefore: Int,
        intensityAfter: Int,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.situation = situation
        self.automaticThought = automaticThought
        self.emotionsStorage = StringArrayStorage.encode(emotions)
        self.distortionsStorage = StringArrayStorage.encode(distortions)
        self.evidenceFor = evidenceFor
        self.evidenceAgainst = evidenceAgainst
        self.balancedThought = balancedThought
        self.intensityBefore = Self.clampIntensity(intensityBefore)
        self.intensityAfter = Self.clampIntensity(intensityAfter)
        self.isDeleted = isDeleted
    }

    static func clampIntensity(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}
