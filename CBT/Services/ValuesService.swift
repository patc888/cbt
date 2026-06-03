import Foundation
import SwiftData

nonisolated struct ValueDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let actionPrompts: [String]
}

nonisolated struct ValueTinyAction: Identifiable, Equatable, Sendable {
    let id: String
    let valueID: String
    let valueName: String
    let title: String
}

nonisolated struct ValuePracticeSummary: Identifiable, Equatable, Sendable {
    let id: String
    let valueName: String
    let count: Int
}

enum ValuesService {
    static let defaultValues: [ValueDefinition] = [
        ValueDefinition(id: "connection", name: "Connection", actionPrompts: [
            "Send a short check-in to someone you care about.",
            "Give someone your full attention for one small moment.",
            "Ask for help with one manageable thing."
        ]),
        ValueDefinition(id: "health", name: "Health", actionPrompts: [
            "Drink a glass of water and notice how your body feels.",
            "Step outside or stretch for two minutes.",
            "Choose one small thing that supports rest tonight."
        ]),
        ValueDefinition(id: "creativity", name: "Creativity", actionPrompts: [
            "Make one rough note, sketch, or idea without polishing it.",
            "Change one small part of your space to feel more alive.",
            "Spend five minutes exploring an idea just because it interests you."
        ]),
        ValueDefinition(id: "rest", name: "Rest", actionPrompts: [
            "Take one quiet minute without multitasking.",
            "Set down one non-urgent thing for later.",
            "Make one choice that lowers the volume of the day."
        ]),
        ValueDefinition(id: "courage", name: "Courage", actionPrompts: [
            "Do one small thing you have been putting off.",
            "Say one honest sentence kindly.",
            "Take the first two minutes of a task that matters."
        ])
    ]

    static func definition(for valueID: String) -> ValueDefinition? {
        let normalizedID = PersonalValue.normalizedID(valueID)
        return defaultValues.first { $0.id == normalizedID }
    }

    static func action(
        for date: Date = Date(),
        selectedValues: [PersonalValue],
        calendar: Calendar = .current
    ) -> ValueTinyAction? {
        let activeValues = selectedValues
            .filter { !$0.isDeleted && !$0.name.isEmpty }
            .sorted { first, second in
                if first.createdAt == second.createdAt {
                    return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
                }
                return first.createdAt < second.createdAt
            }
        guard !activeValues.isEmpty else { return nil }

        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: day)
        let dayIndex = components.day ?? 0
        let value = activeValues[((dayIndex % activeValues.count) + activeValues.count) % activeValues.count]
        let prompts = definition(for: value.valueID)?.actionPrompts ?? [
            "Choose one tiny action that reflects \(value.name) today."
        ]
        let promptIndex = ((dayIndex / max(activeValues.count, 1)) % prompts.count + prompts.count) % prompts.count
        let title = prompts[promptIndex]
        return ValueTinyAction(
            id: "\(value.valueID)-\(promptIndex)",
            valueID: value.valueID,
            valueName: value.name,
            title: title
        )
    }

    @MainActor
    static func selectDefaultValue(
        _ definition: ValueDefinition,
        in modelContext: ModelContext,
        createdAt: Date = Date()
    ) throws -> PersonalValue {
        try selectValue(
            valueID: definition.id,
            name: definition.name,
            isCustom: false,
            createdAt: createdAt,
            in: modelContext
        )
    }

    @MainActor
    static func addCustomValue(
        named name: String,
        in modelContext: ModelContext,
        createdAt: Date = Date()
    ) throws -> PersonalValue? {
        let normalizedName = PersonalValue.normalizedName(name)
        guard !normalizedName.isEmpty else { return nil }
        return try selectValue(
            valueID: PersonalValue.normalizedID(normalizedName),
            name: normalizedName,
            isCustom: true,
            createdAt: createdAt,
            in: modelContext
        )
    }

    @MainActor
    static func complete(
        action: ValueTinyAction,
        on date: Date = Date(),
        reflection: String? = nil,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> ValueActionCompletion {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let valueID = action.valueID

        let descriptor = FetchDescriptor<ValueActionCompletion>(
            predicate: #Predicate<ValueActionCompletion> {
                $0.isDeleted == false &&
                $0.valueID == valueID &&
                $0.createdAt >= dayStart &&
                $0.createdAt < dayEnd
            },
            sortBy: [SortDescriptor(\ValueActionCompletion.createdAt)]
        )

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let completion = ValueActionCompletion(
            valueID: action.valueID,
            valueName: action.valueName,
            actionID: action.id,
            actionTitle: action.title,
            reflection: reflection,
            createdAt: date
        )
        modelContext.insert(completion)
        try modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        return completion
    }

    static func isCompleted(
        action: ValueTinyAction,
        on date: Date,
        completions: [ValueActionCompletion],
        calendar: Calendar = .current
    ) -> Bool {
        completions.contains { completion in
            !completion.isDeleted &&
            completion.valueID == action.valueID &&
            calendar.isDate(completion.createdAt, inSameDayAs: date)
        }
    }

    static func weeklySummary(
        completions: [ValueActionCompletion],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ValuePracticeSummary] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            ?? now.addingTimeInterval(7 * 86_400)
        let grouped = Dictionary(grouping: completions.filter {
            !$0.isDeleted && $0.createdAt >= weekStart && $0.createdAt < weekEnd
        }) { completion in
            completion.valueID
        }

        return grouped.map { valueID, completions in
            ValuePracticeSummary(
                id: valueID,
                valueName: completions.first?.valueName ?? valueID.capitalized,
                count: completions.count
            )
        }
        .sorted { first, second in
            if first.count == second.count {
                return first.valueName.localizedCaseInsensitiveCompare(second.valueName) == .orderedAscending
            }
            return first.count > second.count
        }
    }

    @MainActor
    private static func selectValue(
        valueID: String,
        name: String,
        isCustom: Bool,
        createdAt: Date,
        in modelContext: ModelContext
    ) throws -> PersonalValue {
        let normalizedID = PersonalValue.normalizedID(valueID)
        let descriptor = FetchDescriptor<PersonalValue>(
            predicate: #Predicate<PersonalValue> { $0.valueID == normalizedID },
            sortBy: [SortDescriptor(\PersonalValue.createdAt)]
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = PersonalValue.normalizedName(name)
            existing.isCustom = existing.isCustom || isCustom
            existing.isDeleted = false
            try modelContext.save()
            return existing
        }

        let value = PersonalValue(
            valueID: normalizedID,
            name: name,
            isCustom: isCustom,
            createdAt: createdAt
        )
        modelContext.insert(value)
        try modelContext.save()
        return value
    }
}
