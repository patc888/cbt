import Foundation
import SwiftData

@Model
final class PersonalityAssessmentLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var opennessScore: Double = 0
    var conscientiousnessScore: Double = 0
    var extraversionScore: Double = 0
    var agreeablenessScore: Double = 0
    var neuroticismScore: Double = 0

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        opennessScore: Double,
        conscientiousnessScore: Double,
        extraversionScore: Double,
        agreeablenessScore: Double,
        neuroticismScore: Double
    ) {
        self.id = id
        self.date = date
        self.opennessScore = opennessScore
        self.conscientiousnessScore = conscientiousnessScore
        self.extraversionScore = extraversionScore
        self.agreeablenessScore = agreeablenessScore
        self.neuroticismScore = neuroticismScore
    }
}
