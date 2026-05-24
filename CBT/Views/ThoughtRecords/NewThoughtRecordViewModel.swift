import Foundation
import SwiftData
import os

@Observable
final class NewThoughtRecordViewModel {
    var situation = ""
    var automaticThought = ""
    
    var emotions: [String] = []
    var currentEmotion = ""
    var intensityBefore: Double = 50.0
    
    var distortions: [String] = []
    var currentDistortion = ""
    
    var evidenceFor = ""
    var evidenceAgainst = ""
    
    var balancedThought = ""
    var intensityAfter: Double = 50.0
    
    var currentStep = 0
    var showBreathing = false
    
    let totalSteps = 5
    let feelingPresets = ["Anxious", "Sad", "Angry", "Overwhelmed", "Embarrassed", "Guilty", "Lonely", "Frustrated"]
    let distortionPresets = ["All-or-Nothing Thinking", "Mind Reading", "Catastrophizing", "Overgeneralization", "Emotional Reasoning", "Labeling", "Should Statements"]
    
    var canSave: Bool {
        !situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func addEmotion() {
        let clean = currentEmotion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty, !contains(clean, in: emotions) {
            emotions.append(clean)
        }
        currentEmotion = ""
    }
    
    func addDistortion() {
        let clean = currentDistortion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty, !contains(clean, in: distortions) {
            distortions.append(clean)
        }
        currentDistortion = ""
    }

    func toggleEmotion(_ emotion: String) {
        toggleItem(emotion, in: &emotions)
    }
    
    func toggleDistortion(_ distortion: String) {
        toggleItem(distortion, in: &distortions)
    }
    
    private func toggleItem(_ item: String, in items: inout [String]) {
        if let index = items.firstIndex(where: { matches($0, item) }) {
            items.remove(at: index)
        } else {
            items.append(item)
        }
    }
    
    func contains(_ item: String, in items: [String]) -> Bool {
        items.contains(where: { matches($0, item) })
    }
    
    private func matches(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
    
    @MainActor
    func saveRecord(context: ModelContext) -> ThoughtRecord? {
        guard canSave else { return nil }
        
        do {
            return try context.cbtStore.insertThoughtRecord(
                situation: situation,
                automaticThought: automaticThought,
                emotions: emotions,
                distortions: distortions,
                evidenceFor: evidenceFor,
                evidenceAgainst: evidenceAgainst,
                balancedThought: balancedThought,
                intensityBefore: Int(intensityBefore),
                intensityAfter: Int(intensityAfter)
            )
        } catch {
            AppLogger.make(category: "Data").error("Failed to save thought record: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }
}
