import SwiftUI

struct TimeAppearanceSettingsView: View {
    let preferences: AppPreferences?
    let onUpdate: ((AppPreferences) -> Void) -> Void
    
    @Namespace private var appearanceNamespace
    @Namespace private var fullColorNamespace
    @Namespace private var hapticNamespace
    @Namespace private var completedNamespace
    
    var body: some View {
        TimeSettingsSection(title: "Appearance") {
            // 1. App Theme (Light/Dark/System)
            TimeSegmentedToggle(
                selection: Binding(
                    get: { preferences?.appTheme ?? .system },
                    set: { newValue in
                        onUpdate { $0.appTheme = newValue }
                        // Sync to UserDefaults for static Theme access if needed
                        UserDefaults.standard.set(newValue.rawValue, forKey: "userTheme")
                    }
                ),
                options: AppTheme.allCases,
                titleKey: \.rawValue,
                namespace: appearanceNamespace
            )
            .padding(.bottom, 8)
            
            // 2. Accent Color
            accentColorPicker
            
            // 3. Full Color Theme Toggle
            TimeSettingsRow(title: "Full Color Theme") {
                TimeSegmentedToggle(
                    isOn: Binding(
                        get: { preferences?.isImmersive ?? true },
                        set: { newValue in
                            onUpdate { $0.isImmersive = newValue }
                            UserDefaults.standard.set(newValue, forKey: "appThemeImmersive")
                        }
                    ),
                    namespace: fullColorNamespace
                )
            }

            // 4. Show Completed (Kept as requested)
            TimeSettingsRow(
                icon: "checkmark.circle",
                iconColor: Theme.primaryPurple,
                title: "Show Completed",
                subtitle: "Keep finished blocks visible"
            ) {
                TimeSegmentedToggle(
                    isOn: Binding(
                        get: { preferences?.showsCompletedBlocks ?? true },
                        set: { newValue in
                            onUpdate { $0.showsCompletedBlocks = newValue }
                        }
                    ),
                    namespace: completedNamespace
                )
            }
            
            // 5. Haptic Feedback
            TimeSettingsRow(title: "Haptic Feedback") {
                TimeSegmentedToggle(
                    isOn: Binding(
                        get: { preferences?.hapticsEnabled ?? true },
                        set: { newValue in
                            onUpdate { $0.hapticsEnabled = newValue }
                            UserDefaults.standard.set(newValue, forKey: "hapticsEnabled")
                        }
                    ),
                    namespace: hapticNamespace
                )
            }
        }
    }
    
    private var accentColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent Color")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppColorTheme.allCases) { theme in
                        colorThemeButton(for: theme)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 8)
        }
    }
    
    private func colorThemeButton(for theme: AppColorTheme) -> some View {
        let isSelected = (preferences?.selectedColorTheme ?? .purple) == theme
        
        return ZStack {
            if isSelected {
                Circle()
                    .stroke(Theme.primaryText.opacity(0.8), lineWidth: 2.5)
                    .frame(width: 38, height: 38)
            }
            
            Circle()
                .fill(Color(hex: theme.primaryHex))
                .frame(width: 28, height: 28)
                .shadow(color: Color(hex: theme.primaryHex).opacity(0.4), radius: 3, x: 0, y: 2)
        }
        .frame(width: 38, height: 38)
        .onTapGesture {
            HapticManager.shared.lightImpact()
            onUpdate { $0.selectedColorTheme = theme }
            UserDefaults.standard.set(theme.rawValue, forKey: "appColorTheme")
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}
