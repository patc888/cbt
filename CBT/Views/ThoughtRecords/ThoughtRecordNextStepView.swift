import SwiftUI
import SwiftData
import os

@MainActor
struct ThoughtRecordNextStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    let record: ThoughtRecord
    let onDone: () -> Void

    @State private var showingBreathing = false
    @State private var showingGuidedJournal = false
    @State private var savedHelpfulReframe = false

    private var plan: SmartCoachPlan {
        SmartCoach.nextSteps(for: record)
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    header

                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        Text("Smart Coach")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(DSTheme.secondaryText)
                            .textCase(.uppercase)

                        VStack(spacing: DSSpacing.small) {
                            ForEach(plan.recommendations) { recommendation in
                                recommendationControl(for: recommendation)
                            }
                        }
                    }

                    Button("Done for now") {
                        HapticManager.shared.lightImpact()
                        onDone()
                    }
                    .buttonStyle(DSSecondaryButtonStyle())
                    .padding(.top, DSSpacing.small)
                }
                .padding(DSSpacing.large)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Next Step")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingBreathing) {
            breathingReset
        }
        #else
        .sheet(isPresented: $showingBreathing) {
            breathingReset
                .dsSheetPresentation()
        }
        #endif
        .sheet(isPresented: $showingGuidedJournal) {
            NavigationStack {
                GuidedJournalPickerView()
                    .navigationTitle("Guided Journal")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showingGuidedJournal = false
                            }
                        }
                    }
            }
            .dsSheetPresentation()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            ZStack {
                Circle()
                    .fill(themeManager.selectedColor.opacity(0.14))
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
            }

            VStack(alignment: .leading, spacing: DSSpacing.small) {
                Text(plan.headline)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(plan.subtitle)
                    .font(DSTypography.body)
                    .foregroundStyle(DSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(record.balancedThought)
                    .font(.system(.body, design: .rounded).italic())
                    .foregroundStyle(DSTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(DSSpacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                            .fill(themeManager.selectedColor.opacity(0.08))
                    )
            }
        }
    }

    @ViewBuilder
    private func recommendationControl(for recommendation: SmartCoachRecommendation) -> some View {
        switch recommendation.kind {
        case .breathingReset:
            Button {
                HapticManager.shared.lightImpact()
                showingBreathing = true
            } label: {
                recommendationRow(recommendation)
            }
            .buttonStyle(.plain)

        case .distortionLesson(let distortion):
            NavigationLink {
                DistortionExamplesView(initialCategory: distortion)
            } label: {
                recommendationRow(recommendation)
            }
            .buttonStyle(.plain)

        case .selfCompassionExercise(let exerciseID):
            if let exercise = ExerciseService.shared.exercise(withID: exerciseID) {
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    recommendationRow(recommendation)
                }
                .buttonStyle(.plain)
            } else {
                recommendationRow(recommendation)
            }

        case .guidedJournal:
            Button {
                HapticManager.shared.lightImpact()
                showingGuidedJournal = true
            } label: {
                recommendationRow(recommendation)
            }
            .buttonStyle(.plain)

        case .saveHelpfulReframe:
            Button {
                saveHelpfulReframe()
            } label: {
                recommendationRow(
                    recommendation,
                    titleOverride: savedHelpfulReframe ? "Helpful reframe saved" : nil,
                    iconOverride: savedHelpfulReframe ? "checkmark.circle.fill" : nil
                )
            }
            .buttonStyle(.plain)
            .disabled(savedHelpfulReframe)

        case .reviewLater:
            Button {
                HapticManager.shared.lightImpact()
                onDone()
            } label: {
                recommendationRow(recommendation)
            }
            .buttonStyle(.plain)
        }
    }

    private func recommendationRow(
        _ recommendation: SmartCoachRecommendation,
        titleOverride: String? = nil,
        iconOverride: String? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: DSSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous)
                    .fill(themeManager.selectedColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: iconOverride ?? recommendation.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(titleOverride ?? recommendation.title)
                    .font(DSTypography.button)
                    .foregroundStyle(DSTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recommendation.subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DSSpacing.small)

            Image(systemName: trailingIcon(for: recommendation.kind))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DSTheme.secondaryText)
        }
        .padding(DSSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .fill(DSTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .stroke(DSTheme.separator.opacity(0.25), lineWidth: 1)
        )
    }

    private func trailingIcon(for kind: SmartCoachRecommendation.Kind) -> String {
        switch kind {
        case .breathingReset, .guidedJournal, .saveHelpfulReframe, .reviewLater:
            return "arrow.up.forward.square"
        case .distortionLesson, .selfCompassionExercise:
            return "chevron.right"
        }
    }

    private func saveHelpfulReframe() {
        guard !savedHelpfulReframe else { return }

        let balancedThought = record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !balancedThought.isEmpty else { return }

        do {
            let originalThought = record.automaticThought.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = [
                "Helpful reframe:\n\(balancedThought)",
                originalThought.isEmpty ? nil : "Original thought:\n\(originalThought)"
            ]
            .compactMap { $0 }
            .joined(separator: "\n\n")

            try modelContext.cbtStore.insertJournalEntry(
                title: "Helpful Reframe",
                body: body,
                sourceKind: "thoughtRecord",
                sourceID: record.id.uuidString
            )
            savedHelpfulReframe = true
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Data").error("Failed to save helpful reframe: \(error.localizedDescription, privacy: .private)")
        }
    }

    private var breathingReset: some View {
        NavigationStack {
            BreathingResetView(
                durationSeconds: 60,
                pattern: .box,
                autoStart: true,
                showsDismissControl: true,
                showControls: true,
                hideBackground: false,
                onComplete: nil,
                onDismiss: { showingBreathing = false }
            )
        }
    }
}
