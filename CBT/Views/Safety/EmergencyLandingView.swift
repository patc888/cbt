import SwiftData
import SwiftUI

struct EmergencyLandingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \SafetyPlan.updatedAt, order: .reverse) private var safetyPlans: [SafetyPlan]

    @State private var showingContacts = false

    private var safetyPlan: SafetyPlan? {
        safetyPlans.first
    }

    private var contacts: [EmergencyContact] {
        safetyPlan?.emergencyContacts ?? []
    }

    private let groundingExercises = [
        "Name 5 things you can see, 4 you can feel, 3 you can hear, 2 you can smell, and 1 you can taste.",
        "Press both feet into the floor and slowly describe the pressure, temperature, and texture.",
        "Hold a cool object and notice its weight, edges, and surface for one full minute.",
        "Count backward from 100 by sevens, letting each number bring attention back to the present.",
        "Look around and name three neutral facts about where you are right now."
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.large) {
                        header
                        breathingCard
                        helpCard
                        groundingCard
                    }
                    .padding(DSSpacing.large)
                    .dsSettingsContentWidth()
                }
            }
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
#endif
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 40, height: 40)
                        .background(DSTheme.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                }
                .accessibilityLabel(String(localized: "Close"))
                .padding(DSSpacing.large)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Label(String(localized: "Emergency Support"), systemImage: "cross.case.fill")
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.destructive)

            Text(String(localized: "Take the next steady step."))
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: "Use a quick reset, reach a trusted contact, or ground yourself in the present moment. If you may be in immediate danger, contact local emergency services now."))
                .font(DSTypography.body)
                .foregroundStyle(DSTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.trailing, 48)
    }

    private var breathingCard: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(
                    title: String(localized: "Breathing Exercise"),
                    subtitle: String(localized: "Start a short guided box breathing reset.")
                )

                DSPrimaryButton(title: String(localized: "Start Breathing")) {
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true, pattern: .box)
                    }
                }
            }
        }
    }

    private var helpCard: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(
                    title: String(localized: "I Need Help"),
                    subtitle: contacts.isEmpty
                        ? String(localized: "Add emergency contacts in your Safety Plan.")
                        : String(localized: "Show your saved emergency contact details.")
                )

                DSPrimaryButton(title: String(localized: "I Need Help")) {
                    showingContacts.toggle()
                }

                if showingContacts {
                    if contacts.isEmpty {
                        Text(String(localized: "No emergency contacts are saved yet."))
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                    } else {
                        VStack(spacing: DSSpacing.medium) {
                            ForEach(contacts) { contact in
                                emergencyContactRow(contact)
                            }
                        }
                    }
                }
            }
        }
    }

    private var groundingCard: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(
                    title: String(localized: "Grounding Exercises"),
                    subtitle: String(localized: "Small anchors for the next few minutes.")
                )

                VStack(spacing: DSSpacing.medium) {
                    ForEach(Array(groundingExercises.enumerated()), id: \.offset) { index, exercise in
                        DSListRow(
                            icon: "\(index + 1).circle.fill",
                            iconColor: themeManager.selectedColor,
                            title: exercise
                        ) {
                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    private func emergencyContactRow(_ contact: EmergencyContact) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
            Text(contact.name.isEmpty ? String(localized: "Unnamed Contact") : contact.name)
                .font(DSTypography.listLabel)
                .foregroundStyle(DSTheme.primaryText)

            if !contact.relationship.isEmpty {
                Text(contact.relationship)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
            }

            if !contact.phoneNumber.isEmpty {
                Text(contact.phoneNumber)
                    .font(DSTypography.body.weight(.semibold))
                    .foregroundStyle(themeManager.selectedColor)
                    .textSelection(.enabled)
            }

            if !contact.notes.isEmpty {
                Text(contact.notes)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.medium)
        .background(DSTheme.elevatedFill)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
    }
}
