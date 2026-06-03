import Foundation
import SwiftData
import os

@Observable
final class NewThoughtRecordViewModel {
    var mode: ThoughtRecordMode = .guided
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
    var saveReframe = false
    var favoriteReframe = false
    
    var currentStep = 0
    var showBreathing = false
    var draftRecord: ThoughtRecord?
    
    var totalSteps: Int {
        mode == .quick ? 4 : 5
    }

    let feelingPresets = ["Anxious", "Sad", "Angry", "Overwhelmed", "Embarrassed", "Guilty", "Lonely", "Frustrated"]
    let distortionPresets = [
        "All-or-Nothing Thinking",
        "Mind Reading",
        "Catastrophizing",
        "Overgeneralization",
        "Emotional Reasoning",
        "Labeling",
        "Should Statements",
        "Mental Filter",
        "Discounting the Positive",
        "Personalization"
    ]
    
    var canSave: Bool {
        !situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasDraftContent: Bool {
        canSave ||
        !emotions.isEmpty ||
        !distortions.isEmpty ||
        !evidenceFor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !evidenceAgainst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var draftSignature: String {
        [
            mode.rawValue,
            situation,
            automaticThought,
            emotions.joined(separator: "|"),
            "\(Int(intensityBefore))",
            distortions.joined(separator: "|"),
            evidenceFor,
            evidenceAgainst,
            balancedThought,
            "\(Int(intensityAfter))",
            saveReframe.description,
            favoriteReframe.description
        ].joined(separator: " | ")
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
    func load(record: ThoughtRecord) {
        draftRecord = record
        mode = record.mode
        situation = record.situation
        automaticThought = record.automaticThought
        emotions = record.emotions
        intensityBefore = Double(record.intensityBefore)
        distortions = record.distortions
        evidenceFor = record.evidenceFor
        evidenceAgainst = record.evidenceAgainst
        balancedThought = record.balancedThought
        intensityAfter = Double(record.intensityAfter)
        saveReframe = record.isSavedReframe
        favoriteReframe = record.isFavoriteReframe
    }

    @MainActor
    func saveDraft(context: ModelContext) {
        guard hasDraftContent else { return }

        do {
            draftRecord = try context.cbtStore.saveThoughtRecordDraft(
                existing: draftRecord,
                mode: mode,
                situation: situation,
                automaticThought: automaticThought,
                emotions: emotions,
                distortions: distortions,
                evidenceFor: evidenceFor,
                evidenceAgainst: evidenceAgainst,
                balancedThought: balancedThought,
                intensityBefore: Int(intensityBefore),
                intensityAfter: Int(intensityAfter),
                isSavedReframe: saveReframe,
                isFavoriteReframe: favoriteReframe
            )
        } catch {
            AppLogger.make(category: "Data").error("Failed to save thought record draft: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    func saveRecord(context: ModelContext) -> ThoughtRecord? {
        guard canSave else { return nil }
        
        do {
            return try context.cbtStore.completeThoughtRecord(
                draftRecord,
                mode: mode,
                situation: situation,
                automaticThought: automaticThought,
                emotions: emotions,
                distortions: distortions,
                evidenceFor: evidenceFor,
                evidenceAgainst: evidenceAgainst,
                balancedThought: balancedThought,
                intensityBefore: Int(intensityBefore),
                intensityAfter: Int(intensityAfter),
                isSavedReframe: saveReframe || favoriteReframe,
                isFavoriteReframe: favoriteReframe
            )
        } catch {
            AppLogger.make(category: "Data").error("Failed to save thought record: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }
}
