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

            let snapshot = CloudKitSyncEventSnapshot(event)
            Task { @MainActor [weak self, snapshot] in
                self?.handleSyncEvent(snapshot)
            }
        }
    }

    private func handleSyncEvent(_ event: CloudKitSyncEventSnapshot) {
        let eventName = event.kind.userVisibleDisplayName

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
            if event.kind.shouldUpdateLastSyncDate {
                lastSyncDate = event.endDate ?? Date()
            }
        } else {
            status = .error("\(eventName) ended without success")
            latestEventSummary = "\(eventName) ended without success"
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
