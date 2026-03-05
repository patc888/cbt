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
            SettingsRow(title: "App Theme") {
                SegmentedToggle(
                    selection: $userTheme,
                    options: AppTheme.allCases,
                    titleKey: \.rawValue,
                    namespace: appearanceNamespace
                )
                .frame(width: 180)
            }
            
            accentColorPicker
            
            SettingsRow(title: "Full Color Theme") {
                SegmentedToggle(isOn: $isImmersive, namespace: fullColorNamespace)
                    .frame(width: 110)
            }
            
            SettingsRow(title: "Haptics") {
                SegmentedToggle(isOn: $hapticsEnabled, namespace: hapticNamespace)
                    .frame(width: 110)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Accent Color")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppColorTheme.allCases) { theme in
                        colorThemeButton(for: theme)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 12)
    }
    
    private func colorThemeButton(for theme: AppColorTheme) -> some View {
        let isSelected = selectedTheme == theme
        
        return ZStack {
            if isSelected {
                Circle()
                    .stroke(Theme.primaryColor.opacity(0.35), lineWidth: 3)
                    .frame(width: 42, height: 42)
            }
            
            Circle()
                .fill(Color(hex: theme.primaryHex))
                .frame(width: 30, height: 30)
                .shadow(color: Color(hex: theme.primaryHex).opacity(colorScheme == .dark ? 0.3 : 0.1), radius: isSelected ? 6 : 2, x: 0, y: 2)
        }
        .frame(width: 42, height: 42)
        .onTapGesture {
            HapticManager.shared.lightImpact()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTheme = theme
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }

    private var appIconDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            disclosureHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            
            if isIconExpanded {
                iconSelectionList
                    .padding(.bottom, 12)
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                    Theme.cardBackground
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(width: 60, height: 60)
                    
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
                        .stroke(Theme.primaryColor, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0), radius: colorScheme == .dark ? 4 : 0, x: 0, y: colorScheme == .dark ? 2 : 0)
                
                Text(icon.displayName)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
