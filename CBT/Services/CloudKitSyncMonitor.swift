import CoreData
import Foundation
import Observation

struct CloudKitSyncEventSnapshot: Sendable {
    let identifier: UUID
    let kind: CloudKitSyncEventKind
    let startDate: Date
    let endDate: Date?
    let succeeded: Bool
    let errorDescription: String?

    nonisolated init(_ event: NSPersistentCloudKitContainer.Event) {
        self.identifier = event.identifier
        self.kind = CloudKitSyncEventKind(event.type)
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.succeeded = event.succeeded
        self.errorDescription = event.error?.localizedDescription
    }
}

enum CloudKitSyncEventKind: String, Sendable {
    case setup
    case `import`
    case export
    case unknown

    nonisolated var displayName: String {
        switch self {
        case .setup:
            return "setup"
        case .import:
            return "import"
        case .export:
            return "export"
        case .unknown:
            return "sync"
        }
    }

    nonisolated var userVisibleDisplayName: String {
        switch self {
        case .setup:
            return "CloudKit setup"
        case .import:
            return "iCloud import"
        case .export:
            return "iCloud export"
        case .unknown:
            return "iCloud sync"
        }
    }

    nonisolated var shouldUpdateLastSyncDate: Bool {
        switch self {
        case .setup:
            return false
        case .import, .export, .unknown:
            return true
        }
    }
}

@MainActor
@Observable
final class CloudKitSyncMonitor {
    enum Status: Equatable {
        case syncing
        case upToDate
        case error(String)
    }

    static let shared = CloudKitSyncMonitor()
    private static let lastSyncDateKey = "com.melichan.CBT.cloudSyncStatusMonitor.lastSyncDate"

    private(set) var status: Status = .upToDate
    private(set) var currentEventKind: CloudKitSyncEventKind?
    private(set) var lastCompletedEventKind: CloudKitSyncEventKind?
    private(set) var lastEventDate: Date?
    private(set) var lastSyncDate: Date? {
        didSet {
            persistLastSyncDate()
        }
    }
    private(set) var lastError: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var eventObserver: NSObjectProtocol?
    @ObservationIgnored private var activeEvents: [UUID: CloudKitSyncEventKind] = [:]

    init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter? = nil) {
        self.defaults = defaults
        if let storedDate = defaults.object(forKey: Self.lastSyncDateKey) as? Date {
            self.lastSyncDate = storedDate
        }

        let notificationCenter = notificationCenter ?? .default
        self.notificationCenter = notificationCenter
        eventObserver = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            let snapshot = CloudKitSyncEventSnapshot(event)
            Task { @MainActor [weak self, snapshot] in
                self?.handle(snapshot)
            }
        }
    }

    deinit {
        if let eventObserver {
            notificationCenter.removeObserver(eventObserver)
        }
    }

    var statusText: String {
        switch status {
        case .syncing:
            return "Syncing..."
        case .upToDate:
            return "Up to date"
        case .error:
            return "Error"
        }
    }

    var isSyncing: Bool {
        status == .syncing
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
        case .upToDate:
            return lastSyncDescription
        case .syncing:
            return "Syncing with iCloud"
        case .error(let message):
            return "iCloud sync error: \(message)"
        }
    }

    var lastEventSummary: String {
        if let lastError {
            return "CloudKit \(currentEventKind?.displayName ?? "sync") failed: \(lastError)"
        }

        if let currentEventKind {
            return "CloudKit \(currentEventKind.displayName) in progress"
        }

        if let lastCompletedEventKind {
            return "CloudKit \(lastCompletedEventKind.displayName) completed"
        }

        return "No SwiftData CloudKit events observed this launch."
    }

    private func handle(_ event: CloudKitSyncEventSnapshot) {
        let kind = event.kind
        lastEventDate = event.endDate ?? event.startDate

        if event.endDate == nil {
            activeEvents[event.identifier] = kind
            currentEventKind = kind
            lastError = nil
            status = .syncing
            return
        }

        activeEvents.removeValue(forKey: event.identifier)

        if let errorDescription = event.errorDescription {
            currentEventKind = kind
            lastError = errorDescription
            status = .error(errorDescription)
            return
        }

        guard event.succeeded else {
            currentEventKind = kind
            let message = "CloudKit \(kind.displayName) ended without success."
            lastError = message
            status = .error(message)
            return
        }

        lastCompletedEventKind = kind
        lastError = nil
        if kind.shouldUpdateLastSyncDate {
            lastSyncDate = event.endDate ?? Date()
        }

        if let nextActiveEvent = activeEvents.first {
            currentEventKind = nextActiveEvent.value
            status = .syncing
        } else {
            currentEventKind = nil
            status = .upToDate
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

private extension CloudKitSyncEventKind {
    nonisolated init(_ type: NSPersistentCloudKitContainer.EventType) {
        switch type {
        case .setup:
            self = .setup
        case .import:
            self = .import
        case .export:
            self = .export
        @unknown default:
            self = .unknown
        }
    }
}
