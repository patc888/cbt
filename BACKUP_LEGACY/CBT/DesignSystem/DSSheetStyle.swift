import SwiftUI

struct DSSheetContainer<Content: View>: View {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
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
        .presentationCornerRadius(DSCornerRadius.large)
        .presentationBackground {
            (themeManager?.isImmersive ?? false) ? AnyView(ThemedBackground()) : AnyView(DSTheme.background)
        }
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
