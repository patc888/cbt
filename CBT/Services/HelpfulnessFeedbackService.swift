import Foundation
import SwiftData

@MainActor
struct HelpfulnessFeedbackService {
    static let shared = HelpfulnessFeedbackService()

    @discardableResult
    func record(
        activityKind: HelpfulnessActivityKind,
        response: HelpfulnessResponse,
        itemID: String? = nil,
        note: String? = nil,
        sourceScreen: String? = nil,
        createdAt: Date = Date(),
        in context: ModelContext
    ) throws -> HelpfulnessFeedback {
        let feedback = HelpfulnessFeedback(
            createdAt: createdAt,
            activityKind: activityKind,
            response: response,
            itemID: itemID,
            note: note,
            sourceScreen: sourceScreen
        )
        context.insert(feedback)
        try context.save()
        return feedback
    }

    func recommendationScores(
        from feedback: [HelpfulnessFeedback],
        since cutoff: Date
    ) -> [DailyRecommendationType: Double] {
        var buckets = [DailyRecommendationType: (total: Double, count: Int)]()

        for item in feedback where !item.isDeleted && item.createdAt >= cutoff {
            guard let type = recommendationType(for: item.activityKind) else { continue }
            let current = buckets[type] ?? (total: 0, count: 0)
            buckets[type] = (total: current.total + item.response.score, count: current.count + 1)
        }

        return buckets.reduce(into: [:]) { result, pair in
            guard pair.value.count > 0 else { return }
            result[pair.key] = pair.value.total / Double(pair.value.count)
        }
    }

    private func recommendationType(for kind: HelpfulnessActivityKind) -> DailyRecommendationType? {
        switch kind {
        case .breathing:
            return .breathingReset
        case .activityPlanning:
            return .behavioralActivation
        case .guidedJournal:
            return .guidedJournal
        case .thoughtRecord:
            return .thoughtRecord
        }
    }
}
