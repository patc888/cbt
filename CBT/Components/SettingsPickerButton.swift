import SwiftUI

/// Reusable picker button for settings
struct SettingsPickerButton: View {
    let value: String
    let isExpanded: Bool
    var placeholder: String? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            if value.isEmpty, let placeholder {
                Text(placeholder)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .shadow(color: Theme.primaryColor.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .foregroundStyle(Theme.primaryColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.primaryColor.opacity(isExpanded ? 0.15 : 0.1))
        )
        .overlay(
            Capsule()
                .stroke(Theme.primaryColor, lineWidth: isExpanded ? 2 : 0)
        )
    }
}


/// Variant for frequency/dropdown pickers
struct SettingsDropdownButton: View {
    let value: String
    let isExpanded: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Theme.primaryColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Theme.primaryColor.opacity(isExpanded ? 0.15 : 0.1))
        )
        .overlay(
            Capsule()
                .stroke(Theme.primaryColor, lineWidth: isExpanded ? 2 : 0)
        )
    }
}
