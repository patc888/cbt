import Foundation
import SwiftData

@Model
final class PersonalValue: SoftDeletableRecord {
    var id: UUID = UUID()
    var valueID: String = ""
    var name: String = ""
    var isCustom: Bool = false
    var createdAt: Date = Date()
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        valueID: String,
        name: String,
        isCustom: Bool = false,
        createdAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.valueID = Self.normalizedID(valueID.isEmpty ? name : valueID)
        self.name = Self.normalizedName(name)
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.isDeleted = isDeleted
    }

    nonisolated static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func normalizedID(_ value: String) -> String {
        normalizedName(value)
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }
}

@Model
final class ValueActionCompletion: SoftDeletableRecord {
    var id: UUID = UUID()
    var valueID: String = ""
    var valueName: String = ""
    var actionID: String = ""
    var actionTitle: String = ""
    var reflection: String?
    var createdAt: Date = Date()
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        valueID: String,
        valueName: String,
        actionID: String,
        actionTitle: String,
        reflection: String? = nil,
        createdAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.valueID = PersonalValue.normalizedID(valueID)
        self.valueName = PersonalValue.normalizedName(valueName)
        self.actionID = PersonalValue.normalizedID(actionID)
        self.actionTitle = actionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reflection = reflection
        self.createdAt = createdAt
        self.isDeleted = isDeleted
    }
}
