import Foundation
import SwiftData

@Model
final class AssessmentLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var assessmentType: String = ""
    var score: Int = 0
    var scoreValue: Double?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        assessmentType: String,
        score: Int,
        scoreValue: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.assessmentType = assessmentType
        self.score = score
        self.scoreValue = scoreValue
    }
}
