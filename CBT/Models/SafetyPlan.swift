import Foundation
import SwiftData

struct EmergencyContact: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var relationship: String
    var phoneNumber: String
    var notes: String

    init(
        id: UUID = UUID(),
        name: String = "",
        relationship: String = "",
        phoneNumber: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class SafetyPlan {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var emergencyContactsStorage: String = "[]"
    var personalWarningSignsStorage: String = "[]"
    var copingStrategiesStorage: String = "[]"
    var groundingStepsStorage: String = "[]"
    var safePlacesStorage: String = "[]"
    var remindersStorage: String = "[]"
    var makesItWorseStorage: String = "[]"
    var privacySafeDisplayEnabled: Bool = true

    var emergencyContacts: [EmergencyContact] {
        get { Self.decodeContacts(emergencyContactsStorage) }
        set {
            emergencyContactsStorage = Self.encodeContacts(newValue)
            updatedAt = Date()
        }
    }

    var personalWarningSigns: [String] {
        get { StringArrayStorage.decode(personalWarningSignsStorage) }
        set {
            personalWarningSignsStorage = StringArrayStorage.encode(newValue)
            updatedAt = Date()
        }
    }

    var copingStrategies: [String] {
        get { StringArrayStorage.decode(copingStrategiesStorage) }
        set {
            copingStrategiesStorage = StringArrayStorage.encode(newValue)
            updatedAt = Date()
        }
    }

    var groundingSteps: [String] {
        get { StringArrayStorage.decode(groundingStepsStorage) }
        set {
            groundingStepsStorage = StringArrayStorage.encode(newValue)
            updatedAt = Date()
        }
    }

    var safePlaces: [String] {
        get { StringArrayStorage.decode(safePlacesStorage) }
        set {
            safePlacesStorage = StringArrayStorage.encode(newValue)
            updatedAt = Date()
        }
    }

    var reminders: [String] {
        get { StringArrayStorage.decode(remindersStorage) }
        set {
            remindersStorage = StringArrayStorage.encode(newValue)
            updatedAt = Date()
        }
    }

    var makesItWorse: [String] {
        get { StringArrayStorage.decode(makesItWorseStorage) }
        set {
            makesItWorseStorage = StringArrayStorage.encode(newValue)
            updatedAt = Date()
        }
    }

    var supportivePeople: [EmergencyContact] {
        get { emergencyContacts }
        set { emergencyContacts = newValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        emergencyContacts: [EmergencyContact] = [],
        personalWarningSigns: [String] = [],
        copingStrategies: [String] = [],
        groundingSteps: [String] = [],
        safePlaces: [String] = [],
        reminders: [String] = [],
        makesItWorse: [String] = [],
        privacySafeDisplayEnabled: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.emergencyContactsStorage = Self.encodeContacts(emergencyContacts)
        self.personalWarningSignsStorage = StringArrayStorage.encode(personalWarningSigns)
        self.copingStrategiesStorage = StringArrayStorage.encode(copingStrategies)
        self.groundingStepsStorage = StringArrayStorage.encode(groundingSteps)
        self.safePlacesStorage = StringArrayStorage.encode(safePlaces)
        self.remindersStorage = StringArrayStorage.encode(reminders)
        self.makesItWorseStorage = StringArrayStorage.encode(makesItWorse)
        self.privacySafeDisplayEnabled = privacySafeDisplayEnabled
    }

    private static func encodeContacts(_ contacts: [EmergencyContact]) -> String {
        let normalized = contacts
            .map {
                EmergencyContact(
                    id: $0.id,
                    name: $0.name,
                    relationship: $0.relationship,
                    phoneNumber: $0.phoneNumber,
                    notes: $0.notes
                )
            }
            .filter { !$0.name.isEmpty || !$0.phoneNumber.isEmpty || !$0.relationship.isEmpty || !$0.notes.isEmpty }

        guard
            let data = try? JSONEncoder().encode(normalized),
            let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return json
    }

    private static func decodeContacts(_ value: String) -> [EmergencyContact] {
        guard let data = value.data(using: .utf8) else {
            return []
        }

        return (try? JSONDecoder().decode([EmergencyContact].self, from: data)) ?? []
    }
}
