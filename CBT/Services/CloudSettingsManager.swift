import Foundation
import Combine
import SwiftData
import os.log

protocol CloudKeyValueStoring: AnyObject {
    func object(forKey aKey: String) -> Any?
    func bool(forKey aKey: String) -> Bool
    func string(forKey aKey: String) -> String?
    func set(_ value: Any?, forKey aKey: String)
    @discardableResult
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStoring {}

struct CloudSettingsSnapshot: Equatable {
    let hapticsEnabled: Bool
    let appLockEnabled: Bool
    let discreetModeEnabled: Bool
    let currentIcon: String

    init(settings: UserSettings) {
        self.hapticsEnabled = settings.hapticsEnabled ?? true
        self.appLockEnabled = settings.appLockEnabled ?? false
        self.discreetModeEnabled = settings.discreetModeEnabled ?? false
        self.currentIcon = settings.currentIcon ?? ""
    }
}

@MainActor
final class CloudSettingsManager: ObservableObject {
    static let shared = CloudSettingsManager()

    /// Set by CBTApp at launch so the manager can keep local UserSettings in sync.
    var modelContainer: ModelContainer?

    private let logger = Logger(subsystem: "com.melichan.CBT", category: "CloudSettings")
    private let store: CloudKeyValueStoring
    private let notificationCenter: NotificationCenter
    private var hasCompletedInitialMerge = false
    private var isApplyingCloudValues = false

    init(
        store: CloudKeyValueStoring = NSUbiquitousKeyValueStore.default,
        notificationCenter: NotificationCenter = .default
    ) {
        self.store = store
        self.notificationCenter = notificationCenter

        notificationCenter.addObserver(
            self,
            selector: #selector(storeDidChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        synchronizeStore(reason: "Requested initial NSUbiquitousKeyValueStore sync.")
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func syncToCloud(settings: UserSettings) {
        var didChange = false

        pushCloudValue(settings.hapticsEnabled ?? true, for: .hapticsEnabled, readCloudValue: cloudBool, didChange: &didChange)
        pushCloudValue(settings.appLockEnabled ?? false, for: .appLockEnabled, readCloudValue: cloudBool, didChange: &didChange)
        pushCloudValue(settings.discreetModeEnabled ?? false, for: .discreetModeEnabled, readCloudValue: cloudBool, didChange: &didChange)
        pushCloudValue(settings.currentIcon ?? "", for: .currentIcon, readCloudValue: cloudString, didChange: &didChange)

        if didChange {
            synchronizeStore(reason: "Synchronized settings to NSUbiquitousKeyValueStore.")
        }
    }

    func syncOnLocalChange(settings: UserSettings) {
        guard !isApplyingCloudValues else { return }

        if !hasCompletedInitialMerge {
            performInitialMerge(with: settings)
            hasCompletedInitialMerge = true
            return
        }

        syncToCloud(settings: settings)
    }

    @objc private func storeDidChangeExternally(notification: Notification) {
        logger.info("NSUbiquitousKeyValueStore did change externally.")

        guard let userInfo = notification.userInfo,
              let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        if reasonForChange == NSUbiquitousKeyValueStoreServerChange || reasonForChange == NSUbiquitousKeyValueStoreInitialSyncChange {
            if let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                let relevantKeys = keys.filter(CloudSettingsKey.isKnownName)
                guard !relevantKeys.isEmpty else { return }

                Task { @MainActor in
                    self.pullFromCloud(keys: relevantKeys)
                }
            }
        }
    }

    private func pullFromCloud(keys: [String]) {
        guard let container = modelContainer else {
            logger.error("ModelContainer is not available for pulling cloud settings.")
            return
        }

        let context = container.mainContext

        do {
            let settings = try UserSettings.fetchOrCreate(in: context)

            var didChange = false
            isApplyingCloudValues = true
            defer { isApplyingCloudValues = false }

            applyCloudValueIfChanged(for: .hapticsEnabled, keys: keys, readCloudValue: cloudBool, currentValue: { settings.hapticsEnabled ?? true }, assign: { settings.hapticsEnabled = $0 }, didChange: &didChange)
            applyCloudValueIfChanged(for: .appLockEnabled, keys: keys, readCloudValue: cloudBool, currentValue: { settings.appLockEnabled ?? false }, assign: { cloudValue in
                settings.appLockEnabled = cloudValue
                UserDefaults.standard.set(cloudValue, forKey: "appLockEnabled")
            }, didChange: &didChange)
            applyCloudValueIfChanged(for: .discreetModeEnabled, keys: keys, readCloudValue: cloudBool, currentValue: { settings.discreetModeEnabled ?? false }, assign: { cloudValue in
                settings.discreetModeEnabled = cloudValue
                AppConfiguration.setDiscreetModeEnabled(cloudValue)
            }, didChange: &didChange)
            applyCloudValueIfChanged(for: .currentIcon, keys: keys, readCloudValue: cloudString, currentValue: { settings.currentIcon ?? "" }, assign: { settings.currentIcon = $0.isEmpty ? nil : $0 }, didChange: &didChange)

            if didChange {
                try context.save()
                logger.info("Saved updated cloud settings into local UserSettings.")
            }

        } catch {
            logger.error("Failed to fetch UserSettings for cloud pull: \(error.localizedDescription)")
        }
    }

    private func performInitialMerge(with settings: UserSettings) {
        var shouldPushToCloud = false
        var didUpdateLocalSettings = false

        isApplyingCloudValues = true
        defer { isApplyingCloudValues = false }

        mergeInitialCloudValue(settings.hapticsEnabled ?? true, for: .hapticsEnabled, readCloudValue: cloudBool, assign: { settings.hapticsEnabled = $0 }, didUpdateLocalSettings: &didUpdateLocalSettings, shouldPushToCloud: &shouldPushToCloud)
        mergeInitialCloudValue(settings.appLockEnabled ?? false, for: .appLockEnabled, readCloudValue: cloudBool, assign: { cloudValue in
            settings.appLockEnabled = cloudValue
            UserDefaults.standard.set(cloudValue, forKey: "appLockEnabled")
        }, didUpdateLocalSettings: &didUpdateLocalSettings, shouldPushToCloud: &shouldPushToCloud)
        mergeInitialCloudValue(settings.discreetModeEnabled ?? false, for: .discreetModeEnabled, readCloudValue: cloudBool, assign: { cloudValue in
            settings.discreetModeEnabled = cloudValue
            AppConfiguration.setDiscreetModeEnabled(cloudValue)
        }, didUpdateLocalSettings: &didUpdateLocalSettings, shouldPushToCloud: &shouldPushToCloud)
        mergeInitialCloudValue(settings.currentIcon ?? "", for: .currentIcon, readCloudValue: cloudString, assign: { settings.currentIcon = $0.isEmpty ? nil : $0 }, didUpdateLocalSettings: &didUpdateLocalSettings, shouldPushToCloud: &shouldPushToCloud)

        if didUpdateLocalSettings, let context = settings.modelContext {
            do {
                try context.save()
                logger.info("Initialized local UserSettings from cloud-backed values.")
            } catch {
                logger.error("Failed to save initial cloud settings merge: \(error.localizedDescription)")
            }
        }

        if shouldPushToCloud {
            synchronizeStore(reason: "Seeded NSUbiquitousKeyValueStore from local UserSettings.")
        }
    }

    private func pushCloudValue<Value: Equatable>(
        _ localValue: Value,
        for key: CloudSettingsKey,
        readCloudValue: (CloudSettingsKey) -> Value?,
        didChange: inout Bool
    ) {
        guard readCloudValue(key) != localValue else { return }

        store.set(localValue, forKey: key.rawValue)
        didChange = true
    }

    private func applyCloudValueIfChanged<Value: Equatable>(
        for key: CloudSettingsKey,
        keys: [String],
        readCloudValue: (CloudSettingsKey) -> Value?,
        currentValue: () -> Value,
        assign: (Value) -> Void,
        didChange: inout Bool
    ) {
        guard keys.contains(key.rawValue) else { return }
        guard let cloudValue = readCloudValue(key) else {
            logger.warning("Ignored missing or invalid cloud value for \(key.rawValue, privacy: .public).")
            return
        }
        guard currentValue() != cloudValue else { return }

        assign(cloudValue)
        didChange = true
        logger.info("Updated UserSettings.\(key.rawValue, privacy: .public) from cloud.")
    }

    private func mergeInitialCloudValue<Value: Equatable>(
        _ localValue: Value,
        for key: CloudSettingsKey,
        readCloudValue: (CloudSettingsKey) -> Value?,
        assign: (Value) -> Void,
        didUpdateLocalSettings: inout Bool,
        shouldPushToCloud: inout Bool
    ) {
        if let cloudValue = readCloudValue(key) {
            guard localValue != cloudValue else { return }
            assign(cloudValue)
            didUpdateLocalSettings = true
        } else {
            store.set(localValue, forKey: key.rawValue)
            shouldPushToCloud = true
        }
    }

    private func cloudBool(for key: CloudSettingsKey) -> Bool? {
        guard let object = store.object(forKey: key.rawValue) else { return nil }

        if let value = object as? Bool {
            return value
        }
        if let number = object as? NSNumber {
            return number.boolValue
        }

        return store.bool(forKey: key.rawValue)
    }

    private func cloudString(for key: CloudSettingsKey) -> String? {
        guard store.object(forKey: key.rawValue) != nil else { return nil }
        return store.string(forKey: key.rawValue) ?? ""
    }

    @discardableResult
    private func synchronizeStore(reason: String) -> Bool {
        let didSynchronize = store.synchronize()
        if didSynchronize {
            logger.info("\(reason, privacy: .public)")
        } else {
            logger.error("NSUbiquitousKeyValueStore synchronize returned false: \(reason, privacy: .public)")
        }
        return didSynchronize
    }
}

enum CloudSettingsKey: String, CaseIterable {
    case hapticsEnabled
    case appLockEnabled
    case discreetModeEnabled
    case currentIcon

    nonisolated static let allNames = allCases.map(\.rawValue)

    nonisolated private static let knownNames = Set(allNames)

    nonisolated static func isKnownName(_ name: String) -> Bool {
        knownNames.contains(name)
    }
}
