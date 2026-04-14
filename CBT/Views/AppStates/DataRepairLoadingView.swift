import SwiftUI

struct DataRepairLoadingView: View {
    var isMigrating: Bool = false

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(isMigrating ? "Migrating data..." : "Opening your data...")
                    .font(DSTypography.body)
                
                if isMigrating {
                    Text("This might take a moment if you have a lot of entries.")
                        .font(DSTypography.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}
