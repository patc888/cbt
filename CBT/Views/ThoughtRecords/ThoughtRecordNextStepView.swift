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
    @State private var scheduledReview = false
    @State private var linkedExperiment = false
    @State private var markedPattern = false
    @State private var favoritedSituation = false

    private var plan: SmartCoachPlan {
        SmartCoach.nextSteps(for: record)
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    header

                    reassuranceCard

                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        Text("One next step")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(DSTheme.secondaryText)
                            .textCase(.uppercase)

                        VStack(spacing: DSSpacing.small) {
                            ForEach(plan.recommendations.prefix(1)) { recommendation in
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
        .onAppear {
            savedHelpfulReframe = record.isSavedReframe
            scheduledReview = record.reviewDueAt != nil
            linkedExperiment = !record.linkedExperimentIDs.isEmpty
            markedPattern = !record.relapsePatterns.isEmpty
            favoritedSituation = record.isFavoriteReframe
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
                Text("Thought record saved")
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(plan.headline)
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

    private var reassuranceCard: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.small) {
                Text("Saved.")
                    .font(DSTypography.cardTitle)
                    .foregroundStyle(DSTheme.primaryText)

                Text("You don’t have to solve this right now.")
                    .font(DSTypography.body)
                    .foregroundStyle(DSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

        case .scheduleReReview:
            Button {
                scheduleReview()
            } label: {
                recommendationRow(
                    recommendation,
                    titleOverride: scheduledReview ? "Re-review scheduled" : nil,
                    iconOverride: scheduledReview ? "checkmark.circle.fill" : nil
                )
            }
            .buttonStyle(.plain)
            .disabled(scheduledReview)

        case .beliefCheckIn:
            NavigationLink {
                ReframeReviewDeckView()
            } label: {
                recommendationRow(recommendation)
            }
            .buttonStyle(.plain)

        case .behavioralExperiment(let exerciseID):
            if let exercise = ExerciseService.shared.exercise(withID: exerciseID) {
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                        .onAppear {
                            linkExperiment(exerciseID: exerciseID)
                        }
                } label: {
                    recommendationRow(
                        recommendation,
                        titleOverride: linkedExperiment ? "Experiment linked" : nil,
                        iconOverride: linkedExperiment ? "checkmark.circle.fill" : nil
                    )
                }
                .buttonStyle(.plain)
            } else {
                recommendationRow(recommendation)
            }

        case .relapsePattern:
            Button {
                markRelapsePattern()
            } label: {
                recommendationRow(
                    recommendation,
                    titleOverride: markedPattern ? "Pattern tracked" : nil,
                    iconOverride: markedPattern ? "checkmark.circle.fill" : nil
                )
            }
            .buttonStyle(.plain)
            .disabled(markedPattern)

        case .favoriteBySituation:
            Button {
                favoriteForSituation()
            } label: {
                recommendationRow(
                    recommendation,
                    titleOverride: favoritedSituation ? "Favorited for this situation" : nil,
                    iconOverride: favoritedSituation ? "star.fill" : nil
                )
            }
            .buttonStyle(.plain)
            .disabled(favoritedSituation)

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
        case .breathingReset, .guidedJournal, .saveHelpfulReframe, .scheduleReReview, .relapsePattern, .favoriteBySituation, .reviewLater:
            return "arrow.up.forward.square"
        case .distortionLesson, .selfCompassionExercise, .beliefCheckIn, .behavioralExperiment:
            return "chevron.right"
        }
    }

    private func saveHelpfulReframe() {
        guard !savedHelpfulReframe else { return }

        let balancedThought = record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !balancedThought.isEmpty else { return }

        do {
            try modelContext.cbtStore.updateSavedReframe(record, isSaved: true)
            savedHelpfulReframe = true
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Data").error("Failed to save helpful reframe: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func scheduleReview() {
        guard !scheduledReview else { return }

        let dueAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
        do {
            try modelContext.cbtStore.scheduleReframeFollowUp(record, dueAt: dueAt)
            scheduledReview = true
            savedHelpfulReframe = true
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Data").error("Failed to schedule reframe review: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func linkExperiment(exerciseID: String) {
        guard !linkedExperiment else { return }

        do {
            try modelContext.cbtStore.linkBehavioralExperiment(record, exerciseID: exerciseID)
            linkedExperiment = true
        } catch {
            AppLogger.make(category: "Data").error("Failed to link behavioral experiment: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func markRelapsePattern() {
        guard !markedPattern else { return }

        do {
            try modelContext.cbtStore.addRelapsePattern(record, pattern: record.followUpSituationLabel)
            markedPattern = true
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Data").error("Failed to track relapse pattern: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func favoriteForSituation() {
        guard !favoritedSituation else { return }

        do {
            try modelContext.cbtStore.updateFavoriteReframe(record, isFavorite: true)
            favoritedSituation = true
            savedHelpfulReframe = true
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Data").error("Failed to favorite reframe: \(error.localizedDescription, privacy: .private)")
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
