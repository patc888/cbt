import Foundation
import SwiftData

@Model
final class FlexibleJournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var templateType: String = ""
    var responses: [String] = []
    var valueIDsStorage: String = "[]"
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        templateType: String,
        responses: [String],
        valueIDs: [String] = []
    ) {
        self.id = id
        self.date = date
        self.templateType = templateType
        self.responses = responses
        self.valueIDsStorage = StringArrayStorage.encode(valueIDs.map(PersonalValue.normalizedID))
    }
}

extension FlexibleJournalEntry {
    var valueIDs: [String] {
        get { StringArrayStorage.decode(valueIDsStorage) }
        set { valueIDsStorage = StringArrayStorage.encode(newValue.map(PersonalValue.normalizedID)) }
    }
}
