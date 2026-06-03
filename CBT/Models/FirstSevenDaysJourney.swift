import Foundation
import SwiftData

@Model
final class FirstSevenDaysJourney {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date?
    var isOptIn: Bool = false
    var completedStepIDsStorage: String = ""

    var completedStepIDs: [String] {
        get { StringArrayStorage.decode(completedStepIDsStorage) }
        set { completedStepIDsStorage = StringArrayStorage.encode(newValue) }
    }

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        isOptIn: Bool = false,
        completedStepIDs: [String] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.isOptIn = isOptIn
        self.completedStepIDsStorage = StringArrayStorage.encode(completedStepIDs)
    }
}
