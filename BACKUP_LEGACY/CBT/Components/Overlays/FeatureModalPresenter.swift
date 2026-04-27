import SwiftUI

struct FeatureModalPresenter<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        DSSheetContainer {
            ScrollView {
                VStack {
                    content()
                        .frame(maxWidth: 560)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.small)
            }
            .scrollIndicators(.hidden)
        }
    }
}
