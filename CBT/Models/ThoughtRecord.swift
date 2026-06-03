import Foundation
import SwiftData

@Model
final class ThoughtRecord: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var situation: String = ""
    var automaticThought: String = ""
    var emotionsStorage: String = ""
    var distortionsStorage: String = ""
    var evidenceFor: String = ""
    var evidenceAgainst: String = ""
    var balancedThought: String = ""
    var intensityBefore: Int = 0
    var intensityAfter: Int = 0
    var isSavedReframe: Bool = false
    var isFavoriteReframe: Bool = false
    var savedReframeAt: Date?
    var reviewDueAt: Date?
    var lastReviewedAt: Date?
    var balancedThoughtBeliefLater: Int?
    var balancedThoughtBeliefReviewedAt: Date?
    var linkedExperimentIDsStorage: String = ""
    var relapsePatternStorage: String = ""
    var situationLabel: String = ""
    var updatedAt: Date = Date()
    var completedAt: Date?
    var isDraft: Bool = false
    var modeRawValue: String = ThoughtRecordMode.guided.rawValue
    var isDeleted: Bool = false

    var emotions: [String] {
        get { StringArrayStorage.decode(emotionsStorage) }
        set { emotionsStorage = StringArrayStorage.encode(newValue) }
    }

    var distortions: [String] {
        get { StringArrayStorage.decode(distortionsStorage) }
        set { distortionsStorage = StringArrayStorage.encode(newValue) }
    }

    var linkedExperimentIDs: [String] {
        get { StringArrayStorage.decode(linkedExperimentIDsStorage) }
        set { linkedExperimentIDsStorage = StringArrayStorage.encode(newValue) }
    }

    var relapsePatterns: [String] {
        get { StringArrayStorage.decode(relapsePatternStorage) }
        set { relapsePatternStorage = StringArrayStorage.encode(newValue) }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        situation: String = "",
        automaticThought: String = "",
        emotions: [String] = [],
        distortions: [String] = [],
        evidenceFor: String = "",
        evidenceAgainst: String = "",
        balancedThought: String = "",
        intensityBefore: Int,
        intensityAfter: Int,
        isSavedReframe: Bool = false,
        isFavoriteReframe: Bool = false,
        savedReframeAt: Date? = nil,
        reviewDueAt: Date? = nil,
        lastReviewedAt: Date? = nil,
        balancedThoughtBeliefLater: Int? = nil,
        balancedThoughtBeliefReviewedAt: Date? = nil,
        linkedExperimentIDs: [String] = [],
        relapsePatterns: [String] = [],
        situationLabel: String = "",
        updatedAt: Date? = nil,
        completedAt: Date? = nil,
        isDraft: Bool = false,
        mode: ThoughtRecordMode = .guided,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.situation = situation
        self.automaticThought = automaticThought
        self.emotionsStorage = StringArrayStorage.encode(emotions)
        self.distortionsStorage = StringArrayStorage.encode(distortions)
        self.evidenceFor = evidenceFor
        self.evidenceAgainst = evidenceAgainst
        self.balancedThought = balancedThought
        self.intensityBefore = Self.clampIntensity(intensityBefore)
        self.intensityAfter = Self.clampIntensity(intensityAfter)
        self.isSavedReframe = isSavedReframe
        self.isFavoriteReframe = isFavoriteReframe
        self.savedReframeAt = savedReframeAt ?? (isSavedReframe || isFavoriteReframe ? completedAt ?? createdAt : nil)
        self.reviewDueAt = reviewDueAt
        self.lastReviewedAt = lastReviewedAt
        self.balancedThoughtBeliefLater = balancedThoughtBeliefLater.map(Self.clampIntensity)
        self.balancedThoughtBeliefReviewedAt = balancedThoughtBeliefReviewedAt
        self.linkedExperimentIDsStorage = StringArrayStorage.encode(linkedExperimentIDs)
        self.relapsePatternStorage = StringArrayStorage.encode(relapsePatterns)
        self.situationLabel = situationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = updatedAt ?? createdAt
        self.completedAt = completedAt
        self.isDraft = isDraft
        self.modeRawValue = mode.rawValue
        self.isDeleted = isDeleted
    }

    var mode: ThoughtRecordMode {
        get { ThoughtRecordMode(rawValue: modeRawValue) ?? .guided }
        set { modeRawValue = newValue.rawValue }
    }

    var displayReframe: String {
        balancedThought.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isComplete: Bool {
        !isDraft && (
            completedAt != nil ||
            !balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !evidenceAgainst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    func reframeFollowUpDueDate(calendar: Calendar = .current) -> Date? {
        guard isSavedReframe, !displayReframe.isEmpty else { return nil }
        if let reviewDueAt {
            return reviewDueAt
        }
        let anchor = savedReframeAt ?? completedAt ?? createdAt
        return calendar.date(byAdding: .day, value: 1, to: anchor) ?? anchor.addingTimeInterval(86_400)
    }

    func isReframeFollowUpDue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !isDeleted,
              !isDraft,
              balancedThoughtBeliefLater == nil,
              lastReviewedAt == nil,
              let dueDate = reframeFollowUpDueDate(calendar: calendar)
        else {
            return false
        }

        return now >= dueDate
    }

    var followUpSituationLabel: String {
        let storedLabel = situationLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedLabel.isEmpty {
            return storedLabel
        }

        return Self.makeSituationLabel(from: situation, emotions: emotions, distortions: distortions)
    }

    static func makeSituationLabel(from situation: String, emotions: [String], distortions: [String]) -> String {
        let trimmedSituation = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSituation.isEmpty {
            let words = trimmedSituation.split(separator: " ").prefix(5).joined(separator: " ")
            return words
        }

        if let distortion = distortions.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            return distortion
        }

        if let emotion = emotions.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            return emotion
        }

        return "General"
    }

    static func clampIntensity(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}

enum ThoughtRecordMode: String, CaseIterable, Identifiable {
    case quick
    case guided

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .guided: return "Guided"
        }
    }
}
