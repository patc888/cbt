import Foundation
import SwiftData

@Model
final class JournalEntry: SoftDeletableRecord {
    var id: UUID
    var createdAt: Date
    var title: String
    var body: String
    var sourceKind: String?
    var sourceID: String?
    var durationSeconds: Int?
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        body: String,
        sourceKind: String? = nil,
        sourceID: String? = nil,
        durationSeconds: Int? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.body = body
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.durationSeconds = durationSeconds
        self.isDeleted = isDeleted
    }
}
