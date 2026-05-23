import SwiftUI

#if canImport(UIKit)
/// A UIKit-backed view modifier that forcefully hides the navigation bar.
/// Use this when SwiftUI's `.toolbar(.hidden, for: .navigationBar)` is unreliable.
private struct NavigationBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        HiderController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? HiderController)?.hideNavigationChrome()
        NavigationChromeSuppressor.hideAllVisibleChrome()
    }

    private final class HiderController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            hideNavigationChrome()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hideNavigationChrome()
        }

        func hideNavigationChrome() {
            var controller: UIViewController? = self

            while let current = controller {
                NavigationChromeSuppressor.hideChrome(for: current)

                if let navigationController = current as? UINavigationController {
                    NavigationChromeSuppressor.hideChrome(for: navigationController)
                    return
                }

                if let navigationController = current.navigationController {
                    NavigationChromeSuppressor.hideChrome(for: navigationController)
                    return
                }

                controller = current.parent
            }
        }
    }
}

@MainActor
private enum NavigationChromeSuppressor {
    static func hideAllVisibleChrome() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let roots = scenes.flatMap { $0.windows }.compactMap(\.rootViewController)
        roots.forEach { hideVisibleChrome(in: $0) }
    }

    static func hideChrome(for controller: UIViewController) {
        controller.navigationItem.hidesBackButton = true
        controller.navigationItem.backButtonDisplayMode = .minimal
        controller.navigationItem.leftBarButtonItem = nil

        guard let navigationController = controller as? UINavigationController ?? controller.navigationController else {
            return
        }

        navigationController.topViewController?.navigationItem.hidesBackButton = true
        navigationController.topViewController?.navigationItem.backButtonDisplayMode = .minimal
        navigationController.topViewController?.navigationItem.leftBarButtonItem = nil
        navigationController.visibleViewController?.navigationItem.hidesBackButton = true
        navigationController.visibleViewController?.navigationItem.backButtonDisplayMode = .minimal
        navigationController.visibleViewController?.navigationItem.leftBarButtonItem = nil
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.navigationBar.isHidden = true
    }

    private static func hideVisibleChrome(in controller: UIViewController) {
        hideChrome(for: controller)

        controller.children.forEach { hideVisibleChrome(in: $0) }

        if let presented = controller.presentedViewController {
            hideVisibleChrome(in: presented)
        }
    }
}
#endif

extension View {
    /// Forcefully hides the UIKit navigation bar on iOS.
    func hideNavigationBar() -> some View {
        #if canImport(UIKit)
        self.background(NavigationBarHider())
        #else
        self
        #endif
    }
}
