import SwiftUI

struct DataRepairLoadingView: View {
    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ProgressView("Opening your data...")
                .font(DSTypography.body)
                .padding(24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
                .accessibilityElement(children: .combine)
        }
    }
}
