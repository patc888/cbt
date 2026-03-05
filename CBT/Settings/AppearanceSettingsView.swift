import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    @Binding var userTheme: AppTheme
    @Binding var selectedTheme: AppColorTheme
    @Binding var isImmersive: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var currentIcon: String?
    
    @Namespace private var appearanceNamespace
    @Namespace private var fullColorNamespace
    @Namespace private var hapticNamespace
    
    @State private var isIconExpanded = false
    @State private var errorString: String?
    @State private var showingError = false
    
    var body: some View {
        SettingsSection(title: "Appearance") {
            SegmentedToggle(
                selection: $userTheme,
                options: AppTheme.allCases,
                titleKey: \.rawValue,
                namespace: appearanceNamespace
            )
            
            accentColorPicker
            
            SettingsRow(title: "Full Color Theme") {
                SegmentedToggle(isOn: $isImmersive, namespace: fullColorNamespace)
            }
            
            SettingsRow(title: "Haptic Feedback") {
                SegmentedToggle(isOn: $hapticsEnabled, namespace: hapticNamespace)
            }
            
            appIconDisclosure
        }
        .alert("Error Changing Icon", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                HapticManager.shared.lightImpact()
            }
        } message: {
            Text(errorString ?? "Unknown error")
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
        }
    }
    
    private func colorThemeButton(for theme: AppColorTheme) -> some View {
        let isSelected = selectedTheme == theme
        
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
            withAnimation(.spring(response: 0.3)) {
                selectedTheme = theme
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }

    private var appIconDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            disclosureHeader
            
            if isIconExpanded {
                iconSelectionList
            }
        }
        .onAppear {
            #if canImport(UIKit)
            currentIcon = UIApplication.shared.alternateIconName
            #endif
        }
    }
    
    private var disclosureHeader: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isIconExpanded.toggle()
            }
        }) {
            HStack {
                Text("App Icon")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                
                statusText
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .rotationEffect(.degrees(isIconExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    
    private var statusText: some View {
        Group {
            if let iconName = currentIcon, 
               let icon = AppIcon.allCases.first(where: { $0.iconName == iconName }) {
                Text(icon.displayName)
            } else {
                Text("Default")
            }
        }
        .font(.system(size: 14, design: .rounded))
        .foregroundStyle(Theme.secondaryText)
    }

    
    private var iconSelectionList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AppIcon.allCases) { icon in
                    iconButton(for: icon)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func iconButton(for icon: AppIcon) -> some View {
        let isSelected = currentIcon == icon.iconName
        
        return Button(action: {
            HapticManager.shared.lightImpact()
            #if canImport(UIKit)
            UIApplication.shared.setAlternateIconName(icon.iconName) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        HapticManager.shared.error()
                        self.errorString = error.localizedDescription
                        self.showingError = true
                    }
                } else {
                    HapticManager.shared.success()
                    withAnimation {
                        currentIcon = icon.iconName
                    }
                }
            }
            #endif
        }) {
            VStack(spacing: 8) {
                ZStack {
                    #if canImport(UIKit)
                    Image(uiImage: UIImage(named: icon.previewImage) ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(12)
                    #else
                    if let nsImage = NSImage(named: icon.previewImage) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                    }
                    #endif
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.primaryText, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Text(icon.displayName)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
