import SwiftUI

/// Reusable toggle row matching the canonical Settings layout.
/// Uses `SettingsRow` and `SegmentedToggle` internally for consistency across all modal sheets and settings views.
struct ToggleRow: View {
    let icon: String?
    let iconColor: Color?
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var disabled: Bool

    init(
        icon: String? = nil,
        iconColor: Color? = nil,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.disabled = disabled
    }

    var body: some View {
        SettingsRow(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle
        ) {
            SegmentedToggle(isOn: $isOn)
                .frame(width: 110)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
        .frame(minHeight: 44)
    }
}
