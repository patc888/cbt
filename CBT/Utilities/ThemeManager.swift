import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Observable
final class ThemeManager {
    var selectedTheme: AppColorTheme = .cyan {
        didSet { saveTheme() }
    }

    var isImmersive: Bool = false {
        didSet { saveImmersive() }
    }

    var appTheme: AppTheme = .system {
        didSet { saveAppTheme() }
    }

    private let defaults = UserDefaults.standard

    var selectedColor: Color {
        Color(hex: selectedTheme.primaryHex)
    }

    var secondaryColor: Color {
        Color(hex: selectedTheme.secondaryHex)
    }

    init() {
        if let storedTheme = defaults.string(forKey: "appColorTheme"),
           let theme = AppColorTheme(rawValue: storedTheme) {
            self.selectedTheme = theme
        }

        if let storedAppTheme = defaults.string(forKey: "userTheme"),
           let theme = AppTheme(rawValue: storedAppTheme) {
            self.appTheme = theme
        }

        self.isImmersive = defaults.bool(forKey: "appThemeImmersive")
    }

    private func saveTheme() {
        defaults.set(selectedTheme.rawValue, forKey: "appColorTheme")
    }

    private func saveAppTheme() {
        defaults.set(appTheme.rawValue, forKey: "userTheme")
    }

    private func saveImmersive() {
        defaults.set(isImmersive, forKey: "appThemeImmersive")
    }

    var primaryColor: Color {
        Color(hex: selectedTheme.primaryHex)
    }

    var backgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(UIColor.secondarySystemBackground)
        #endif
    }

    var tertiaryBackground: Color {
        if isImmersive {
            #if os(macOS)
            return Color(nsColor: .controlBackgroundColor)
            #else
            return Color(.secondarySystemBackground)
            #endif
        }
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color(.tertiarySystemBackground)
        #endif
    }

    func trackBackgroundColor(for scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color.white.opacity(0.25)
        }
        return Color.gray.opacity(0.12)
    }
}
