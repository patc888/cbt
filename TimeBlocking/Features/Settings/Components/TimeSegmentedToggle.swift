import SwiftUI

/// Unified segmented control component for all toggle and segmented control needs
/// Supports binary toggles, multi-option selectors, and custom labels
struct TimeSegmentedToggle<T: Hashable, Label: View>: View {
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
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    // HapticManager call omitted if not available or replace with system haptic
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
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
                                        .adaptiveShadow(
                                            color: selectionColor(for: option).opacity(0.2),
                                            radius: 3,
                                            x: 0,
                                            y: 2
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(height: 32)
            }
        }
        .padding(.horizontal, 2)
        .background(Theme.toggleBackgroundColor(for: colorScheme))
        .clipShape(Capsule())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
    }
    
    /// Determine selection color (accent color or gray for "Off" states)
    private func selectionColor(for option: T) -> Color {
        // If an active color is explicitly provided, use it
        if let activeColor = activeColor {
            return activeColor
        }
        
        // For binary toggles with Bool, use gray for false
        if let boolValue = option as? Bool, !boolValue {
            return Color.gray
        }
        // For string-based toggles, use gray for "Off"
        if let stringValue = option as? String, stringValue.lowercased() == "off" {
            return Color.gray
        }
        return Theme.primaryAccent
    }
}

// MARK: - Convenience Initializers

// String-based titles
extension TimeSegmentedToggle where Label == Text {
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

// KeyPath-based titles (for Identifiable types)
extension TimeSegmentedToggle where Label == Text, T: Identifiable {
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

// Binary toggle convenience
extension TimeSegmentedToggle where Label == Text, T == Bool {
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
