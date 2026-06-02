import SwiftUI

struct ContextualHelpButton: View {
    let title: String
    let message: String
    @State private var showingHelp = false
    
    var body: some View {
        Button {
            HapticManager.shared.lightImpact()
            showingHelp = true
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(34), expands: false, tint: Theme.primaryColor, hapticType: nil))
        .accessibilityLabel("Help for \(title)")
        .sheet(isPresented: $showingHelp) {
            FeatureModalPresenter {
                DSFeatureModal(
                    systemImage: "info.circle.fill",
                    title: title,
                    subtitle: message,
                    primaryTitle: String(localized: "Got it"),
                    primaryAction: {
                        HapticManager.shared.lightImpact()
                        showingHelp = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        showingHelp = false
                    }
                )
            }
            .dsSheetPresentation(detents: [.fraction(0.34), .medium])
        }
    }
}
