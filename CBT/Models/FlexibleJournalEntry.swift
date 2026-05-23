import Foundation
import SwiftData

@Model
final class FlexibleJournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var templateType: String = ""
    var responses: [String] = []
    
    init(id: UUID = UUID(), date: Date = Date(), templateType: String, responses: [String]) {
        self.id = id
        self.date = date
        self.templateType = templateType
        self.responses = responses
    }
}
