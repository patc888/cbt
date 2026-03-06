import Foundation

struct BreathingPattern: Codable, Equatable, Hashable {
    let name: String
    let inhaleDuration: Double
    let hold1Duration: Double
    let exhaleDuration: Double
    let hold2Duration: Double
    
    let inhaleGuidance: String
    let hold1Guidance: String
    let exhaleGuidance: String
    let hold2Guidance: String
    
    static let box = BreathingPattern(
        name: "Box Breathing",
        inhaleDuration: 4.0,
        hold1Duration: 4.0,
        exhaleDuration: 4.0,
        hold2Duration: 4.0,
        inhaleGuidance: "Through your nose",
        hold1Guidance: "Hold gently",
        exhaleGuidance: "Slow exhale",
        hold2Guidance: "Hold empty"
    )
    
    static let relaxing478 = BreathingPattern(
        name: "4-7-8 Breathing",
        inhaleDuration: 4.0,
        hold1Duration: 7.0,
        exhaleDuration: 8.0,
        hold2Duration: 0.0,
        inhaleGuidance: "Through your nose",
        hold1Guidance: "Hold your breath",
        exhaleGuidance: "With a whoosh",
        hold2Guidance: ""
    )
}
