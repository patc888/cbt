import SwiftUI

/// Unified segmented control component for all toggle and segmented control needs
/// Supports binary toggles, multi-option selectors, and custom labels
struct SegmentedToggle<T: Hashable, Label: View>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> Label
    var namespace: Namespace.ID?
    var fontSize: CGFloat = 11
    var verticalPadding: CGFloat = 6
    var useMinWidth: Bool = false
    var minWidth: CGFloat = 60
    var hideUnselectedLabels: Bool = false
    var activeColor: Color? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Namespace private var internalNamespace
    
    init(
        selection: Binding<T>,
        options: [T],
        namespace: Namespace.ID? = nil,
        fontSize: CGFloat = 11,
        verticalPadding: CGFloat = 6,
        useMinWidth: Bool = false,
        minWidth: CGFloat = 60,
        hideUnselectedLabels: Bool = false,
        activeColor: Color? = nil,
        @ViewBuilder label: @escaping (T) -> Label
    ) {
        self._selection = selection
        self.options = options
        self.namespace = namespace
        self.fontSize = fontSize
        self.verticalPadding = verticalPadding
        self.useMinWidth = useMinWidth
        self.minWidth = minWidth
        self.hideUnselectedLabels = hideUnselectedLabels
        self.activeColor = activeColor
        self.label = label
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button(action: {
                    guard selection != option else { return }
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = option
                    }
                }) {
                    label(option)
                        .foregroundColor(selection == option ? .white : Theme.unselectedOptionColor(for: colorScheme))
                        .opacity(hideUnselectedLabels && selection != option ? 0 : 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.vertical, verticalPadding)
                        .frame(width: useMinWidth ? minWidth : nil)
                        .frame(maxWidth: useMinWidth ? nil : .infinity)
                        .background(
                            ZStack {
                                if selection == option {
                                    Capsule()
                                        .fill(selectionColor(for: option))
                                        .matchedGeometryEffect(
                                            id: namespace != nil ? "selection" : "internal_selection",
                                            in: namespace ?? internalNamespace
                                        )
                                        .shadow(
                                            color: selectionColor(for: option).opacity(colorScheme == .dark ? 0.2 : 0),
                                            radius: colorScheme == .dark ? 3 : 0,
                                            x: 0,
                                            y: colorScheme == .dark ? 2 : 0
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(height: 32)
            }
        }
        .background(
            Capsule()
                .fill(Theme.trackBackgroundColor(for: colorScheme))
        )
        .padding(.horizontal, 2)

        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
    }
    
    private func selectionColor(for option: T) -> Color {
        if let activeColor = activeColor {
            return activeColor
        }
        if let boolValue = option as? Bool, !boolValue {
            return Color.gray
        }
        if let stringValue = option as? String, stringValue.lowercased() == "off" {
            return Color.gray
        }
        return themeManager.selectedColor
    }
}

// MARK: - Convenience Initializers

extension SegmentedToggle where Label == Text {
    init(
        selection: Binding<T>,
        options: [T],
        namespace: Namespace.ID? = nil,
        fontSize: CGFloat = 11,
        verticalPadding: CGFloat = 6,
        useMinWidth: Bool = false,
        minWidth: CGFloat = 60,
        title: @escaping (T) -> String
    ) {
        self.init(
            selection: selection,
            options: options,
            namespace: namespace,
            fontSize: fontSize,
            verticalPadding: verticalPadding,
            useMinWidth: useMinWidth,
            minWidth: minWidth
        ) { option in
            Text(title(option))
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
        }
    }
}

extension SegmentedToggle where Label == Text, T: Identifiable {
    init(
        selection: Binding<T>,
        options: [T],
        titleKey: KeyPath<T, String>,
        namespace: Namespace.ID? = nil,
        fontSize: CGFloat = 11,
        verticalPadding: CGFloat = 6
    ) {
        self.init(
            selection: selection,
            options: options,
            namespace: namespace,
            fontSize: fontSize,
            verticalPadding: verticalPadding
        ) { option in
            Text(option[keyPath: titleKey])
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
        }
    }
}

extension SegmentedToggle where Label == Text, T == Bool {
    init(
        isOn: Binding<Bool>,
        namespace: Namespace.ID? = nil,
        fontSize: CGFloat = 11,
        minWidth: CGFloat = 60
    ) {
        self.init(
            selection: isOn,
            options: [false, true],
            namespace: namespace,
            fontSize: fontSize,
            verticalPadding: 6,
            useMinWidth: true,
            minWidth: minWidth
        ) { value in
            Text(value ? "On" : "Off")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
        }
    }
}
