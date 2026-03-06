import SwiftUI
import Observation

@Observable
final class ThemeManager {
    var selectedTheme: AppColorTheme = .blue {
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
        Color(UIColor.secondarySystemBackground)
    }

    var tertiaryBackground: Color {
        if isImmersive {
            return Color(.secondarySystemBackground)
        }
        return Color(.tertiarySystemBackground)
    }

    func trackBackgroundColor(for scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color.white.opacity(0.25)
        }
        return Color.gray.opacity(0.12)
    }
}
