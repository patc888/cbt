import Foundation
import SwiftData

nonisolated struct TinyWin: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let prompt: String
    let actionTitle: String
    let durationSeconds: Int
    let systemImage: String
}

enum TinyWinCardState: Equatable {
    case empty
    case available(TinyWin)
    case completed(TinyWin)
    case missed(TinyWin)
}

enum TinyWinService {
    static let wins: [TinyWin] = [
        TinyWin(
            id: "three_slow_breaths",
            title: "Take 3 slow breaths",
            prompt: "Let the exhale be a little longer than the inhale.",
            actionTitle: "Done",
            durationSeconds: 30,
            systemImage: "wind"
        ),
        TinyWin(
            id: "name_one_thought",
            title: "Name one thought",
            prompt: "Notice a thought and name it simply, like planning, worrying, or remembering.",
            actionTitle: "I named one",
            durationSeconds: 45,
            systemImage: "brain.head.profile"
        ),
        TinyWin(
            id: "write_helpful_reframe",
            title: "Write one helpful reframe",
            prompt: "Choose one thought and make it a little more balanced or kind.",
            actionTitle: "Reframed",
            durationSeconds: 90,
            systemImage: "lightbulb.fill"
        ),
        TinyWin(
            id: "notice_one_emotion",
            title: "Notice one emotion",
            prompt: "Name what is here without needing to fix it.",
            actionTitle: "Noticed",
            durationSeconds: 30,
            systemImage: "heart.text.square.fill"
        ),
        TinyWin(
            id: "choose_one_value",
            title: "Choose one value for today",
            prompt: "Pick one value you want to keep near you, even in a small way.",
            actionTitle: "Chosen",
            durationSeconds: 45,
            systemImage: "star.circle.fill"
        ),
        TinyWin(
            id: "did_despite_discomfort",
            title: "Write one thing you did despite discomfort",
            prompt: "Give yourself credit for one action, even if it was tiny.",
            actionTitle: "Wrote it",
            durationSeconds: 60,
            systemImage: "checkmark.seal.fill"
        ),
        TinyWin(
            id: "identify_one_trigger",
            title: "Identify one trigger",
            prompt: "Name one moment, place, thought, or sensation that shifted your mood.",
            actionTitle: "Identified",
            durationSeconds: 60,
            systemImage: "scope"
        ),
        TinyWin(
            id: "kind_sentence",
            title: "Write one kind sentence to yourself",
            prompt: "Use the same tone you would offer someone you care about.",
            actionTitle: "Written",
            durationSeconds: 60,
            systemImage: "pencil.and.scribble"
        )
    ]

    static func win(for date: Date, calendar: Calendar = .current, wins: [TinyWin] = Self.wins) -> TinyWin? {
        guard !wins.isEmpty else { return nil }
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: day)
        let dayIndex = components.day ?? 0
        let normalizedIndex = ((dayIndex % wins.count) + wins.count) % wins.count
        return wins[normalizedIndex]
    }

    @MainActor
    static func complete(
        win: TinyWin,
        on date: Date = Date(),
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> TinyWinCompletion {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        let descriptor = FetchDescriptor<TinyWinCompletion>(
            predicate: #Predicate<TinyWinCompletion> {
                $0.isDeleted == false &&
                $0.createdAt >= dayStart &&
                $0.createdAt < dayEnd
            },
            sortBy: [SortDescriptor(\TinyWinCompletion.createdAt)]
        )

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let completion = TinyWinCompletion(createdAt: date, winID: win.id)
        modelContext.insert(completion)
        try modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        return completion
    }

    static func isCompleted(on date: Date, completions: [TinyWinCompletion], calendar: Calendar = .current) -> Bool {
        completions.contains { completion in
            !completion.isDeleted && calendar.isDate(completion.createdAt, inSameDayAs: date)
        }
    }

    static func state(
        for date: Date,
        completions: [TinyWinCompletion],
        now: Date = Date(),
        calendar: Calendar = .current,
        wins: [TinyWin] = Self.wins
    ) -> TinyWinCardState {
        guard let win = win(for: date, calendar: calendar, wins: wins) else { return .empty }
        if isCompleted(on: date, completions: completions, calendar: calendar) {
            return .completed(win)
        }

        let selectedDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        if selectedDay < today {
            return .missed(win)
        }

        return .available(win)
    }
}
