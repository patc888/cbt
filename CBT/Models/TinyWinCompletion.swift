import Foundation
import SwiftData

@Model
final class TinyWinCompletion: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var winID: String = ""
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        winID: String,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.winID = winID
        self.isDeleted = isDeleted
    }
}
