import Foundation
import SwiftData

protocol QuerySignatureRecord: SoftDeletableRecord {
    var createdAt: Date { get }
    func hashQueryContents(into hasher: inout Hasher)
}

extension MoodEntry: QuerySignatureRecord {
    func hashQueryContents(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(createdAt.timeIntervalSinceReferenceDate)
        hasher.combine(isDeleted)
        hasher.combine(moodScore)
        hasher.combine(emotions)
        hasher.combine(triggers)
        hasher.combine(notes ?? "")
        hasher.combine(intensity ?? -1)
    }
}

extension ThoughtRecord: QuerySignatureRecord {
    func hashQueryContents(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(createdAt.timeIntervalSinceReferenceDate)
        hasher.combine(isDeleted)
        hasher.combine(situation)
        hasher.combine(automaticThought)
        hasher.combine(emotions)
        hasher.combine(distortions)
        hasher.combine(evidenceFor)
        hasher.combine(evidenceAgainst)
        hasher.combine(balancedThought)
        hasher.combine(intensityBefore)
        hasher.combine(intensityAfter)
    }
}

extension ExerciseCompletion: QuerySignatureRecord {
    func hashQueryContents(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(createdAt.timeIntervalSinceReferenceDate)
        hasher.combine(isDeleted)
        hasher.combine(exerciseID)
        hasher.combine(notes ?? "")
    }
}

extension JournalEntry: QuerySignatureRecord {
    func hashQueryContents(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(createdAt.timeIntervalSinceReferenceDate)
        hasher.combine(isDeleted)
        hasher.combine(title)
        hasher.combine(body)
        hasher.combine(sourceKind ?? "")
        hasher.combine(sourceID ?? "")
        hasher.combine(durationSeconds ?? -1)
    }
}

enum QueryChangeSignature {
    static func make<Record: QuerySignatureRecord>(for records: [Record]) -> String {
        var hasher = Hasher()
        hasher.combine(records.count)

        for record in records {
            record.hashQueryContents(into: &hasher)
        }

        return "\(records.count):\(hasher.finalize())"
    }
}
