import CoreData
import Combine
import Foundation

@MainActor
final class CloudSyncStatusMonitor: ObservableObject {
    static let shared = CloudSyncStatusMonitor()

    enum Status: Equatable {
        case synced
        case syncing
        case error(String)
    }

    @Published private(set) var status: Status = .synced
    @Published private(set) var lastSyncDate: Date? {
        didSet {
            persistLastSyncDate()
        }
    }
    @Published private(set) var latestEventSummary: String = "No sync events observed this launch."

    private static let lastSyncDateKey = "com.melichan.CBT.cloudSyncStatusMonitor.lastSyncDate"

    private let defaults: UserDefaults
    private var eventObserver: NSObjectProtocol?

    private struct EventSnapshot: Sendable {
        let displayName: String
        let endDate: Date?
        let succeeded: Bool
        let errorDescription: String?
        let shouldUpdateLastSyncDate: Bool
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let storedDate = defaults.object(forKey: Self.lastSyncDateKey) as? Date {
            self.lastSyncDate = storedDate
        }
        observeSyncEvents()
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    var lastSyncDescription: String {
        guard let lastSyncDate else {
            return "Not synced yet"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last synced \(formatter.localizedString(for: lastSyncDate, relativeTo: Date()))"
    }

    var accessibilityLabel: String {
        switch status {
        case .synced:
            return lastSyncDescription
        case .syncing:
            return "Syncing with iCloud"
        case .error(let message):
            return "iCloud sync error: \(message)"
        }
    }

    private func observeSyncEvents() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            let eventName = Self.displayName(for: event.type)
            let snapshot = EventSnapshot(
                displayName: eventName,
                endDate: event.endDate,
                succeeded: event.succeeded,
                errorDescription: event.error?.localizedDescription,
                shouldUpdateLastSyncDate: Self.shouldUpdateLastSyncDate(for: event.type)
            )
            Task { @MainActor [weak self, snapshot] in
                self?.handleSyncEvent(snapshot)
            }
        }
    }

    private func handleSyncEvent(_ event: EventSnapshot) {
        let eventName = event.displayName

        if let errorDescription = event.errorDescription {
            status = .error(errorDescription)
            latestEventSummary = "\(eventName) failed"
            return
        }

        if event.endDate == nil {
            status = .syncing
            latestEventSummary = "\(eventName) in progress"
            return
        }

        if event.succeeded {
            status = .synced
            latestEventSummary = "\(eventName) completed"
            if event.shouldUpdateLastSyncDate {
                lastSyncDate = event.endDate ?? Date()
            }
        } else {
            status = .error("\(eventName) ended without success")
            latestEventSummary = "\(eventName) ended without success"
        }
    }

    private static func displayName(for eventType: NSPersistentCloudKitContainer.EventType) -> String {
        switch eventType {
        case .setup:
            return "CloudKit setup"
        case .import:
            return "iCloud import"
        case .export:
            return "iCloud export"
        @unknown default:
            return "iCloud sync"
        }
    }

    private static func shouldUpdateLastSyncDate(for eventType: NSPersistentCloudKitContainer.EventType) -> Bool {
        switch eventType {
        case .import, .export:
            return true
        case .setup:
            return false
        @unknown default:
            return true
        }
    }

    private func persistLastSyncDate() {
        guard let lastSyncDate else {
            defaults.removeObject(forKey: Self.lastSyncDateKey)
            return
        }

        defaults.set(lastSyncDate, forKey: Self.lastSyncDateKey)
    }
}
