import Foundation
import SwiftData

@Model
final class JournalEntry: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String = ""
    var body: String = ""
    var sourceKind: String?
    var sourceID: String?
    var durationSeconds: Int?
    var valueIDsStorage: String = "[]"
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        body: String,
        sourceKind: String? = nil,
        sourceID: String? = nil,
        durationSeconds: Int? = nil,
        valueIDs: [String] = [],
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.body = body
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.durationSeconds = durationSeconds
        self.valueIDsStorage = StringArrayStorage.encode(valueIDs.map(PersonalValue.normalizedID))
        self.isDeleted = isDeleted
    }
}

extension JournalEntry {
    var valueIDs: [String] {
        get { StringArrayStorage.decode(valueIDsStorage) }
        set { valueIDsStorage = StringArrayStorage.encode(newValue.map(PersonalValue.normalizedID)) }
    }

    var sessionSourceKind: SessionSourceKind? {
        guard let sourceKind else { return nil }
        return SessionSourceKind(rawValue: sourceKind)
    }

    var durationLabel: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        return DurationFormatting.sessionLabel(seconds: durationSeconds)
    }

    var sessionMetadataLine: String? {
        let parts = [
            sessionSourceKind?.displayName,
            durationLabel
        ]
        .compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
