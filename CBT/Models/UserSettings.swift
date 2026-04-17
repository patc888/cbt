import Foundation
import SwiftData

/// App settings model for CBT
@Model
final class UserSettings {
    @Attribute(.unique) var singletonID: String
    var uuid: UUID? = UUID()
    
    /// Appearance Settings
    var hapticsEnabled: Bool? = true
    var currentIcon: String?
    
    /// Security Settings
    var appLockEnabled: Bool? = false
    
    init(
        hapticsEnabled: Bool = true,
        appLockEnabled: Bool = false,
        singletonID: String = "default"
    ) {
        self.singletonID = singletonID
        self.uuid = UUID()
        self.hapticsEnabled = hapticsEnabled
        self.appLockEnabled = appLockEnabled
    }
}

extension UserSettings {
    static let singletonKey = "default"

    @MainActor
    static func fetchOrCreate(in context: ModelContext) throws -> UserSettings {
        if let settings = try reconcileSingleton(in: context, shouldSaveIfChanged: true) {
            return settings
        }

        let newSettings = UserSettings()
        context.insert(newSettings)
        try context.save()
        return newSettings
    }

    @MainActor
    static func fetchAppLockEnabled(from context: ModelContext) throws -> Bool {
        try reconcileSingleton(in: context, shouldSaveIfChanged: false)?.appLockEnabled == true
    }

    @MainActor
    static func setAppLockEnabled(_ isEnabled: Bool, in context: ModelContext) throws {
        let settings: UserSettings

        if let existing = try reconcileSingleton(in: context, shouldSaveIfChanged: false) {
            settings = existing
        } else {
            settings = UserSettings()
            context.insert(settings)
        }

        settings.appLockEnabled = isEnabled
        try context.save()
    }

    @discardableResult
    @MainActor
    static func reconcileSingleton(in context: ModelContext, shouldSaveIfChanged: Bool = true) throws -> UserSettings? {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.includePendingChanges = true

        let allSettings = try context.fetch(descriptor)
        guard let canonical = canonicalSettings(from: allSettings) else {
            return nil
        }

        var didChange = false

        if canonical.singletonID != singletonKey {
            canonical.singletonID = singletonKey
            didChange = true
        }

        for duplicate in allSettings where duplicate.persistentModelID != canonical.persistentModelID {
            context.delete(duplicate)
            didChange = true
        }

        if didChange && shouldSaveIfChanged {
            try context.save()
        }

        return canonical
    }

    @MainActor
    private static func canonicalSettings(from allSettings: [UserSettings]) -> UserSettings? {
        allSettings.sorted { lhs, rhs in
            let lhsKey = lhs.uuid?.uuidString ?? String(describing: lhs.persistentModelID)
            let rhsKey = rhs.uuid?.uuidString ?? String(describing: rhs.persistentModelID)
            return lhsKey < rhsKey
        }
        .first
    }
}
