import Foundation
import SwiftData

@Model
final class ProgramProgress: SoftDeletableRecord {
    var id: UUID = UUID()
    var programID: String = ""
    var completedDays: Int = 0
    var lastCompletedAt: Date?
    var isDeleted: Bool = false
    
    init(
        id: UUID = UUID(),
        programID: String,
        completedDays: Int = 0,
        lastCompletedAt: Date? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.programID = programID
        self.completedDays = completedDays
        self.lastCompletedAt = lastCompletedAt
        self.isDeleted = isDeleted
    }
}
