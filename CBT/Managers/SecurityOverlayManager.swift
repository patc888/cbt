import SwiftUI
import Combine
import OSLog

@MainActor
final class SecurityOverlayManager: ObservableObject {
    private var window: UIWindow?
    private var cancellables = Set<AnyCancellable>()
    
    private let securityManager: SecurityManager
    private let themeManager: ThemeManager
    private weak var windowScene: UIWindowScene?
    
    init(securityManager: SecurityManager, themeManager: ThemeManager, windowScene: UIWindowScene? = nil) {
        self.securityManager = securityManager
        self.themeManager = themeManager
        self.windowScene = windowScene
        
        setupContentProtectionObservation()
    }

    func updateScene(_ scene: UIWindowScene) {
        self.windowScene = scene
        // If already showing but on the wrong scene (unlikely but possible during multitasking shifts),
        // we might want to re-anchor, but for now just updating the reference is enough.
    }
    
    private func setupContentProtectionObservation() {
        // Observe both isContentProtected and isLocked to ensure the overlay is shown when needed
        securityManager.$isContentProtected
            .receive(on: RunLoop.main)
            .sink { [weak self] isProtected in
                if isProtected {
                    self?.showOverlay()
                } else {
                    self?.hideOverlay()
                }
            }
            .store(in: &cancellables)
    }
    
    private func showOverlay() {
        guard window == nil else { 
            // If already shown, ensure it's visible and key
            window?.isHidden = false
            window?.makeKeyAndVisible()
            return 
        }
        
        // Use the captured scene if available, otherwise fallback to the most appropriate active scene
        // (Fallback is for safety, but captured scene is preferred for multi-window stability)
        let targetScene: UIWindowScene?
        if let captured = windowScene {
            targetScene = captured
        } else {
            let scenes = UIApplication.shared.connectedScenes
            targetScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ??
                          scenes.first(where: { $0.activationState == .foregroundInactive }) as? UIWindowScene
        }

        guard let windowScene = targetScene else {
            AppLogger.make(category: "SecurityOverlay").warning("No valid window scene found for security overlay")
            return
        }
        
        let newWindow = UIWindow(windowScene: windowScene)
        // .alert + 1 ensures it's above normal alerts and sheets
        newWindow.windowLevel = .alert + 1
        
        let overlayView = SecurityCoverRoot()
            .environment(themeManager)
            .environmentObject(securityManager)
        
        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = .clear
        
        newWindow.rootViewController = hostingController
        newWindow.isHidden = false
        newWindow.makeKeyAndVisible()
        
        self.window = newWindow
    }
    
    private func hideOverlay() {
        window?.isHidden = true
        window = nil
    }
}
