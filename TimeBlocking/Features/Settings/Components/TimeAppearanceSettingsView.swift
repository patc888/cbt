import SwiftUI

struct TimeAppearanceSettingsView: View {
    let preferences: AppPreferences?
    let onUpdate: ((AppPreferences) -> Void) -> Void
    
    @Namespace private var appearanceNamespace
    @Namespace private var fullColorNamespace
    @Namespace private var hapticNamespace
    @Namespace private var completedNamespace
    
    var body: some View {
        TimeSettingsSection(
            title: "Appearance"
        ) {
            TimeSegmentedToggle(
                selection: Binding(
                    get: { preferences?.appTheme ?? .system },
                    set: { newValue in
                        onUpdate { $0.appTheme = newValue }
                    }
                ),
                options: AppTheme.allCases,
                titleKey: \.rawValue,
                namespace: appearanceNamespace
            )
            .padding(.bottom, 8)
            
            accentColorPicker
            
            TimeSettingsRow(title: "Full Color Theme") {
                TimeSegmentedToggle(
                    isOn: Binding(
                        get: { preferences?.isImmersive ?? true },
                        set: { newValue in
                            onUpdate { $0.isImmersive = newValue }
                        }
                    ),
                    namespace: fullColorNamespace
                )
            }

            TimeSettingsRow(title: "Show Completed") {
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

            TimeSettingsRow(title: "Haptics") {
                TimeSegmentedToggle(
                    isOn: Binding(
                        get: { preferences?.hapticsEnabled ?? true },
                        set: { newValue in
                            onUpdate { $0.hapticsEnabled = newValue }
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
        let isSelected = (preferences?.selectedColorTheme ?? .red) == theme
        
        return ZStack {
            if isSelected {
                Circle()
                    .stroke(Theme.primaryText.opacity(0.8), lineWidth: 2.5)
                    .frame(width: 38, height: 38)
            }
            
            Circle()
                .fill(Color(hex: theme.primaryHex))
                .frame(width: 28, height: 28)
                .adaptiveShadow(color: Color(hex: theme.primaryHex).opacity(0.4), radius: 3, x: 0, y: 2)
        }
        .frame(width: 38, height: 38)
        .onTapGesture {
            HapticManager.shared.lightImpact()
            onUpdate { $0.selectedColorTheme = theme }
        }

        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}
