import SwiftUI

struct DSSheetContainer<Content: View>: View {
    let maxContentWidth: CGFloat?
    @ViewBuilder let content: () -> Content

    init(
        maxContentWidth: CGFloat? = 640,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxContentWidth = maxContentWidth
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            content()
        }
        .padding(DSSpacing.xLarge)
        .frame(maxWidth: maxContentWidth ?? .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(DSTheme.background)
        .dsSheetPresentation()
    }
}

struct DSSheetPresentationModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let detents: Set<PresentationDetent>?
    let dragIndicator: Visibility

    @ViewBuilder
    func body(content: Content) -> some View {
        if let detents {
            content
                .presentationDetents(detents)
                .dsSheetChrome(dragIndicator: dragIndicator, themeManager: themeManager)
        } else {
            content
                .dsSheetChrome(dragIndicator: dragIndicator, themeManager: themeManager)
        }
    }
}

private struct DSSheetChromeModifier: ViewModifier {
    let dragIndicator: Visibility
    let themeManager: ThemeManager?

    func body(content: Content) -> some View {
        content
            .presentationCornerRadius(DSCornerRadius.large)
            .presentationDragIndicator(dragIndicator)
            .presentationBackground {
                if themeManager?.isImmersive ?? false {
                    ThemedBackground()
                } else {
                    DSTheme.background
                }
            }
    }
}

extension View {
    func dsSheetPresentation(
        detents: Set<PresentationDetent>? = nil,
        dragIndicator: Visibility = .visible
    ) -> some View {
        modifier(DSSheetPresentationModifier(detents: detents, dragIndicator: dragIndicator))
    }

    fileprivate func dsSheetChrome(
        dragIndicator: Visibility,
        themeManager: ThemeManager?
    ) -> some View {
        modifier(DSSheetChromeModifier(dragIndicator: dragIndicator, themeManager: themeManager))
    }
}

struct DSSegmentedPickerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .padding(.horizontal, DSSpacing.large)
            .padding(.vertical, DSSpacing.xSmall)
    }
}

extension View {
    func dsSegmentedPickerStyle() -> some View {
        modifier(DSSegmentedPickerStyle())
    }
}
