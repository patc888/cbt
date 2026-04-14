import Foundation
import UserNotifications
import CoreLocation
import AVFoundation
import Photos
import SwiftUI
import Observation
import OSLog

@Observable @MainActor
final class PermissionManager {
    private static let logger = Logger(subsystem: "com.cbt.app", category: "PermissionManager")
    static let shared = PermissionManager()

    private init() {}

    enum PermissionType {
        case notifications
        case locationWhenInUse
        case camera
        case microphone
        
        var localizedName: String {
            switch self {
            case .notifications: return String(localized: "Notifications")
            case .locationWhenInUse: return String(localized: "Location")
            case .camera: return String(localized: "Camera")
            case .microphone: return String(localized: "Microphone")
            }
        }
    }

    enum Status {
        case notDetermined
        case denied
        case authorized
        case limited // Specific to Photos/Location in some contexts
        
        var isAuthorized: Bool {
            self == .authorized || self == .limited
        }
    }

    private let locationManager = CLLocationManager()
    


    // MARK: - Check Status

    func status(for type: PermissionType) async -> Status {
        switch type {
        case .notifications:
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .authorized, .provisional, .ephemeral: return .authorized
            @unknown default: return .notDetermined
            }
            
        case .locationWhenInUse:
            switch locationManager.authorizationStatus {
            case .notDetermined: return .notDetermined
            case .restricted, .denied: return .denied
            case .authorizedAlways, .authorizedWhenInUse: return .authorized
            @unknown default: return .notDetermined
            }
            
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .notDetermined: return .notDetermined
            case .restricted, .denied: return .denied
            case .authorized: return .authorized
            @unknown default: return .notDetermined
            }
            
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .notDetermined: return .notDetermined
            case .restricted, .denied: return .denied
            case .authorized: return .authorized
            @unknown default: return .notDetermined
            }
        }
    }

    // MARK: - Request Permission

    func request(_ type: PermissionType) async -> Status {
        Self.logger.info("Requesting permission for \(String(describing: type), privacy: .public)")
        
        switch type {
        case .notifications:
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                return granted ? .authorized : .denied
            } catch {
                Self.logger.error("Failed to request notification auth: \(error.localizedDescription, privacy: .public)")
                return .denied
            }
            
        case .locationWhenInUse:
            return await withCheckedContinuation { continuation in
                let delegate = LocationDelegate { status in
                    continuation.resume(returning: status)
                }
                // Keep strong reference to delegate during request
                objc_setAssociatedObject(locationManager, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                locationManager.delegate = delegate
                locationManager.requestWhenInUseAuthorization()
            }
            
        case .camera:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
            
        case .microphone:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .authorized : .denied
        }
    }

    // MARK: - Utilities

    func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Location Helper

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let completion: (PermissionManager.Status) -> Void
    
    init(completion: @escaping (PermissionManager.Status) -> Void) {
        self.completion = completion
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        
        let permissionStatus: PermissionManager.Status
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            permissionStatus = .authorized
        case .denied, .restricted:
            permissionStatus = .denied
        default:
            permissionStatus = .notDetermined
        }
        
        completion(permissionStatus)
        manager.delegate = nil
    }
}
