import CoreData
import Foundation
import Observation

@MainActor
@Observable
final class CloudKitSyncMonitor {
    enum Status: Equatable {
        case syncing
        case upToDate
        case error(String)
    }

    enum EventKind: String, Sendable {
        case setup
        case `import`
        case export
        case unknown

        var displayName: String {
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
    }

    static let shared = CloudKitSyncMonitor()

    private(set) var status: Status = .upToDate
    private(set) var currentEventKind: EventKind?
    private(set) var lastCompletedEventKind: EventKind?
    private(set) var lastEventDate: Date?
    private(set) var lastError: String?

    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var eventObserver: NSObjectProtocol?
    @ObservationIgnored private var activeEvents: [UUID: EventKind] = [:]

    private struct EventSnapshot: Sendable {
        let identifier: UUID
        let kind: EventKind
        let startDate: Date
        let endDate: Date?
        let succeeded: Bool
        let errorDescription: String?

        init(_ event: NSPersistentCloudKitContainer.Event) {
            self.identifier = event.identifier
            self.kind = EventKind(event.type)
            self.startDate = event.startDate
            self.endDate = event.endDate
            self.succeeded = event.succeeded
            self.errorDescription = event.error?.localizedDescription
        }
    }

    init(notificationCenter: NotificationCenter? = nil) {
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

            let snapshot = EventSnapshot(event)
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

    private func handle(_ event: EventSnapshot) {
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

        if let nextActiveEvent = activeEvents.first {
            currentEventKind = nextActiveEvent.value
            status = .syncing
        } else {
            currentEventKind = nil
            status = .upToDate
        }
    }
}

private extension CloudKitSyncMonitor.EventKind {
    init(_ type: NSPersistentCloudKitContainer.EventType) {
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
