import Foundation
import CloudKit
import CoreData
import Observation
import OSLog
import SwiftUI

/// Monitors CloudKit sync status and iCloud account availability for SwiftData/CoreData.
@Observable
@MainActor
final class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()
    
    enum SyncStatus: Equatable {
        case disabled
        case noAccount
        case syncing
        case synced
        case error(String)
        
        var localizedDescription: String {
            switch self {
            case .disabled: return String(localized: "Sync Disabled")
            case .noAccount: return String(localized: "iCloud Account Required")
            case .syncing: return String(localized: "Syncing...")
            case .synced: return String(localized: "Up to Date")
            case .error(let message): return String(localized: "Sync Error: \(message)")
            }
        }
        
        var iconName: String {
            switch self {
            case .disabled: return "icloud.slash"
            case .noAccount: return "person.crop.circle.badge.exclamationmark"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            }
        }
        
        var color: Color {
            switch self {
            case .disabled: return .secondary
            case .noAccount: return .orange
            case .syncing: return .blue
            case .synced: return .green
            case .error: return .red
            }
        }
    }
    
    var status: SyncStatus = .disabled
    var lastSyncDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastCloudSyncDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastCloudSyncDate")
        }
    }
    
    private let logger = AppLogger.make(category: "CloudSync")
    private var accountStatus: CKAccountStatus = .couldNotDetermine
    private var isSyncing = false
    private var refreshTask: Task<Void, Never>?
    private var hasSetupObservers = false
    
    private init() {}

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Starts monitoring iCloud account status. Called explicitly after app boot to prevent launch traps.
    func startMonitoring() {
        guard !hasSetupObservers else { return }
        hasSetupObservers = true
        setupObservers()
        refreshAccountStatus()
    }
    
    private func setupObservers() {
        // CloudKit sync events from NSPersistentCloudKitContainer (used by SwiftData under the hood)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
        
        // iCloud account changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAccountStatus),
            name: NSNotification.Name.CKAccountChanged,
            object: nil
        )
        
        // Refresh on foreground to catch account changes
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAccountStatus),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #else
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshAccountStatus),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }
    
    @objc func refreshAccountStatus() {
        guard DataResetManager.isCloudSyncEnabled else {
            self.status = .disabled
            return
        }

        // Guard against redundant concurrent refreshes
        refreshTask?.cancel()
        refreshTask = Task {
            do {
                let container = CKContainer(identifier: SharedPersistence.cloudKitContainerID)
                let status = try await container.accountStatus()
                if Task.isCancelled { return }
                
                self.accountStatus = status
                self.updateStatus()
                self.logger.info("iCloud account status updated: \(status.rawValue, privacy: .public)")
            } catch {
                if Task.isCancelled { return }
                self.logger.error("Failed to fetch iCloud account status: \(error.localizedDescription, privacy: .private)")
                self.status = .error(error.localizedDescription)
            }
        }
    }
    
    @objc private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }
        
        Task { @MainActor in
            if event.succeeded {
                if event.endDate != nil {
                    self.lastSyncDate = event.endDate
                }
                self.isSyncing = false
                self.updateStatus()
            } else if let error = event.error {
                self.isSyncing = false
                self.logger.error("CloudKit sync event error: \(error.localizedDescription, privacy: .private)")
                self.status = .error(error.localizedDescription)
            } else {
                // Event started
                self.isSyncing = true
                self.updateStatus()
            }
        }
    }
    
    private func updateStatus() {
        // Check if sync is even enabled in the app
        guard DataResetManager.isCloudSyncEnabled else {
            self.status = .disabled
            return
        }
        
        // Check account status
        switch accountStatus {
        case .available:
            if isSyncing {
                self.status = .syncing
            } else {
                self.status = .synced
            }
        case .noAccount:
            self.status = .noAccount
        case .restricted:
            self.status = .error(String(localized: "iCloud access restricted"))
        case .couldNotDetermine:
            self.status = .error(String(localized: "Could not determine iCloud status"))
        case .temporarilyUnavailable:
            self.status = .error(String(localized: "iCloud temporarily unavailable"))
        @unknown default:
            self.status = .error(String(localized: "Unknown iCloud status"))
        }
    }
}
