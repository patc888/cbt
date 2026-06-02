import Foundation
import SwiftData

@Model
final class ChallengeSession {
    var id: UUID = UUID()
    var challengeID: String = ""
    var currentStepIndex: Int = 0
    var isCompleted: Bool = false
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        challengeID: String,
        currentStepIndex: Int = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.challengeID = challengeID
        self.currentStepIndex = max(0, currentStepIndex)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    func getNextStep<Step>(from steps: [Step]) -> Step? {
        guard !steps.isEmpty else {
            markCompletedIfNeeded()
            return nil
        }

        if currentStepIndex >= steps.count {
            markCompletedIfNeeded()
            return nil
        }

        return steps[currentStepIndex]
    }

    @discardableResult
    func advance(totalSteps: Int) -> Bool {
        let totalSteps = max(0, totalSteps)
        let wasCompleted = isCompleted

        guard totalSteps > 0 else {
            markCompletedIfNeeded()
            return !wasCompleted && isCompleted
        }

        if currentStepIndex < totalSteps {
            currentStepIndex += 1
        }

        if currentStepIndex >= totalSteps {
            currentStepIndex = totalSteps
            markCompletedIfNeeded()
        }

        return !wasCompleted && isCompleted
    }

    func syncWithCompletedSteps(_ completedStepCount: Int, totalSteps: Int) {
        let boundedTotal = max(0, totalSteps)
        currentStepIndex = min(max(0, completedStepCount), boundedTotal)

        if boundedTotal > 0, currentStepIndex >= boundedTotal {
            markCompletedIfNeeded()
        } else {
            isCompleted = false
            completedAt = nil
        }
    }

    private func markCompletedIfNeeded() {
        guard !isCompleted else { return }
        isCompleted = true
        completedAt = Date()
    }
}
