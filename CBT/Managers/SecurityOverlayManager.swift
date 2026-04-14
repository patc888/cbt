import SwiftUI
import Combine

@MainActor
final class SecurityOverlayManager: ObservableObject {
    private var window: UIWindow?
    private var cancellables = Set<AnyCancellable>()
    
    private let securityManager: SecurityManager
    private let themeManager: ThemeManager
    
    init(securityManager: SecurityManager, themeManager: ThemeManager) {
        self.securityManager = securityManager
        self.themeManager = themeManager
        
        setupContentProtectionObservation()
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
        
        // Find the active scene
        // We use a slight delay or wait for a scene to be active if needed, 
        // but usually during app launch or foregrounding, there's a scene.
        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? 
                                scenes.first(where: { $0.activationState == .foregroundInactive }) as? UIWindowScene else {
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
