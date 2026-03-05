import SwiftUI

struct WhatIsCBTView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FeatureModalPresenter {
            DSFeatureModal(
                title: "What is CBT?",
                subtitle: "CBT is a practical self-reflection method for noticing patterns and trying more balanced responses.",
                bullets: [
                    DSBullet(icon: "checkmark.circle", text: "Identify unhelpful thoughts"),
                    DSBullet(icon: "arrow.triangle.2.circlepath", text: "Reframe with balanced alternatives"),
                    DSBullet(icon: "figure.mind.and.body", text: "Build habits with small exercises")
                ],
                primaryTitle: "Got it",
                primaryAction: { dismiss() },
                secondaryTitle: "Close",
                secondaryAction: { dismiss() },
                closeAction: { dismiss() }
            )
        }
    }
}
