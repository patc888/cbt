import SwiftUI

struct TipOfTheDayModal: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        FeatureModalPresenter {
            DSFeatureModal(
                title: String(localized: "Tip for Today"),
                subtitle: String(localized: "Try naming one thought before reacting. Even a short pause can make the next step clearer."),
                bullets: [
                    DSBullet(icon: "brain", text: String(localized: "Notice the thought")),
                    DSBullet(icon: "arrow.triangle.2.circlepath", text: String(localized: "Check for alternatives")),
                    DSBullet(icon: "checkmark.circle", text: String(localized: "Choose a small next action"))
                ],
                primaryTitle: String(localized: "Got it"),
                primaryAction: {
                    HapticManager.shared.lightImpact()
                    isPresented = false
                },
                secondaryTitle: String(localized: "Close"),
                secondaryAction: {
                    HapticManager.shared.lightImpact()
                    isPresented = false
                },
                closeAction: {
                    HapticManager.shared.lightImpact()
                    isPresented = false
                }
            )
        }
    }
}
