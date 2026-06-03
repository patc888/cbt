import Foundation
import SwiftData

enum AppTonePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case gentle
    case direct
    case clinical
    case minimal
    case encouraging

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .direct: return "Direct"
        case .clinical: return "Clinical"
        case .minimal: return "Minimal"
        case .encouraging: return "Encouraging"
        }
    }

    var settingsDescription: String {
        switch self {
        case .gentle: return "Soft, low-pressure wording"
        case .direct: return "Clear and straightforward"
        case .clinical: return "Neutral and skills-focused"
        case .minimal: return "Short, quiet labels"
        case .encouraging: return "Warm and motivating"
        }
    }

    var previewText: String {
        switch self {
        case .gentle: return "Take one manageable step."
        case .direct: return "Choose your next step."
        case .clinical: return "Select an intervention to continue."
        case .minimal: return "Next step"
        case .encouraging: return "You can take the next step."
        }
    }
}

/// App settings model for CBT
@Model
final class UserSettings {
    var singletonID: String = "default"
    var uuid: UUID? = UUID()
    
    /// Appearance Settings
    var hapticsEnabled: Bool? = true
    var currentIcon: String?
    var tonePreference: String? = AppTonePreference.gentle.rawValue
    
    /// Security Settings
    var appLockEnabled: Bool? = false
    var discreetModeEnabled: Bool? = false
    
    /// Subscription Settings
    var isPremium: Bool? = false
    
    init(
        hapticsEnabled: Bool = true,
        appLockEnabled: Bool = false,
        discreetModeEnabled: Bool = false,
        isPremium: Bool = false,
        tonePreference: AppTonePreference = .gentle,
        singletonID: String = "default"
    ) {
        self.singletonID = singletonID
        self.uuid = UUID()
        self.hapticsEnabled = hapticsEnabled
        self.appLockEnabled = appLockEnabled
        self.discreetModeEnabled = discreetModeEnabled
        self.isPremium = isPremium
        self.tonePreference = tonePreference.rawValue
    }
}

extension UserSettings {
    var appTonePreference: AppTonePreference {
        get { AppTonePreference(rawValue: tonePreference ?? "") ?? .gentle }
        set { tonePreference = newValue.rawValue }
    }

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
    static func canonicalSettings(from allSettings: [UserSettings]) -> UserSettings? {
        allSettings.sorted { lhs, rhs in
            let lhsKey = lhs.uuid?.uuidString ?? String(describing: lhs.persistentModelID)
            let rhsKey = rhs.uuid?.uuidString ?? String(describing: rhs.persistentModelID)
            return lhsKey < rhsKey
        }
        .first
    }
}
