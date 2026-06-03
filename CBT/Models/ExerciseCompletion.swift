import Foundation
import SwiftData

@Model
final class ExerciseCompletion: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var exerciseID: String = ""
    var notes: String?
    var valueIDsStorage: String = "[]"
    var adaptiveMode: String = DailyPlanMode.full.rawValue
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        exerciseID: String,
        notes: String? = nil,
        valueIDs: [String] = [],
        adaptiveMode: String = DailyPlanMode.full.rawValue,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.exerciseID = exerciseID
        self.notes = notes
        self.valueIDsStorage = StringArrayStorage.encode(valueIDs.map(PersonalValue.normalizedID))
        self.adaptiveMode = Self.normalizedAdaptiveMode(adaptiveMode)
        self.isDeleted = isDeleted
    }

    nonisolated static func normalizedAdaptiveMode(_ value: String?) -> String {
        guard let value, DailyPlanMode(rawValue: value) != nil else {
            return DailyPlanMode.full.rawValue
        }
        return value
    }
}

extension ExerciseCompletion {
    var valueIDs: [String] {
        get { StringArrayStorage.decode(valueIDsStorage) }
        set { valueIDsStorage = StringArrayStorage.encode(newValue.map(PersonalValue.normalizedID)) }
    }
}
