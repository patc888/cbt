import SwiftUI

struct MoodCheckinSavedSummary {
    let createdAt: Date
    let color: MoodColor?
    let intensity: Int
    let emotions: [String]
    let triggers: [String]
    let activityTags: [String]
    let sensations: [String]
    let contextTags: [String]
    let notes: String
}

struct MoodCheckinNextStepState {
    let summary: MoodCheckinSavedSummary
    let plan: MoodCheckInNextStepPlan
    let isFirstMoodCheckIn: Bool
}

struct MoodCheckinNextStepView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    let state: MoodCheckinNextStepState
    let onSkip: () -> Void
    let onGoHome: () -> Void
    let onJournalMore: () -> Void

    @State private var showingBreathing = false
    @State private var breathingDurationSeconds = 60
    @State private var showingThoughtRecord = false
    @State private var showingSafetySupport = false
    @State private var reminderPromptMoment: ReminderOptInMoment?
    @State private var isHandlingReminderPrompt = false

    private var accent: Color {
        state.summary.color?.color(with: themeManager.selectedColor) ?? themeManager.selectedColor
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                    .padding(.top, 18)

                reassuranceCard

                savedSummaryCard

                if shouldSurfaceNeedHelpNow {
                    NeedHelpNowCard(
                        message: String(localized: "Open your rough patch plan and support resources before things build further. If you might be in immediate danger, contact local emergency services now. In the U.S. you can call or text 988 for crisis support.")
                    ) {
                        openSafetySupport()
                    }
                }

                if let reminderPromptMoment {
                    ReminderOptInPromptView(
                        moment: reminderPromptMoment,
                        isWorking: isHandlingReminderPrompt,
                        onAccept: {
                            handleReminderPromptAccepted(reminderPromptMoment)
                        },
                        onDismiss: {
                            handleReminderPromptDismissed(reminderPromptMoment)
                        }
                    )
                }

                nextStepsSection

                footerActions
                    .padding(.top, 2)
                    .padding(.bottom, DSSpacing.large)
            }
            .padding(.horizontal, DSSpacing.large)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingThoughtRecord) {
            NewThoughtRecordFlowView()
                .dsSheetPresentation()
        }
        .sheet(isPresented: $showingSafetySupport) {
            NavigationStack {
                SafetyPlanView()
            }
            .dsSheetPresentation()
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingBreathing) {
            breathingView
        }
        #else
        .sheet(isPresented: $showingBreathing) {
            breathingView
                .dsSheetPresentation()
        }
        #endif
        .task(id: state.summary.createdAt) {
            reminderPromptMoment = await ReminderOptInService.shared.promptIfEligible(
                for: .firstMoodCheckIn,
                hasReachedMoment: state.isFirstMoodCheckIn
            )
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.13))
                    .frame(width: 74, height: 74)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 8) {
                Text("Check-in saved")
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var reassuranceCard: some View {
        MoodGlassPanel(accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
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

    private var savedSummaryCard: some View {
        MoodGlassPanel(accent: accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.14))
                            .frame(width: 54, height: 54)

                        if let color = state.summary.color {
                            color.icon(size: 26)
                                .foregroundStyle(color.iconColor(with: themeManager.selectedColor))
                        } else {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.summary.color?.label ?? "Mood")
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(DSTheme.primaryText)

                        Text("Intensity \(state.summary.intensity)/10 - \(state.summary.createdAt.formatted(date: .omitted, time: .shortened))")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                if !state.summary.emotions.isEmpty {
                    nextStepChipSection(title: "Emotions", items: state.summary.emotions)
                }

                let contextItems = state.summary.triggers + state.summary.activityTags + state.summary.sensations + state.summary.contextTags
                if !contextItems.isEmpty {
                    nextStepChipSection(title: "Context", items: Array(contextItems.prefix(8)))
                }

                let trimmedNotes = state.summary.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)

                        Text(trimmedNotes)
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("One next step")
                .font(DSTypography.sectionTitle)
                .foregroundStyle(DSTheme.primaryText)
                .padding(.horizontal, 2)

            VStack(spacing: 10) {
                ForEach(state.plan.recommendations.prefix(1)) { recommendation in
                    recommendationControl(for: recommendation)
                }
            }
        }
    }

    private var shouldSurfaceNeedHelpNow: Bool {
        state.plan.recommendations.contains { $0.destination == .safetySupport } ||
            (state.summary.color?.rawValue ?? 5) <= 2 ||
            state.summary.intensity >= 8 ||
            hasDistressSignal
    }

    private var hasDistressSignal: Bool {
        let distressKeywords = [
            "stress", "stressed", "overwhelmed", "panic", "anxious", "anxiety",
            "unsafe", "danger", "crisis", "hopeless", "trapped"
        ]
        let values = state.summary.emotions +
            state.summary.triggers +
            state.summary.activityTags +
            state.summary.sensations +
            state.summary.contextTags +
            [state.summary.notes]

        return values.contains { value in
            let lowercased = value.lowercased()
            return distressKeywords.contains { lowercased.contains($0) }
        }
    }

    private var footerActions: some View {
        Button {
            onGoHome()
        } label: {
            Label("Done for now", systemImage: "checkmark")
        }
        .buttonStyle(DSSecondaryButtonStyle())
    }

    @ViewBuilder
    private func recommendationControl(for recommendation: DailyRecommendation) -> some View {
        switch recommendation.destination {
        case .breathingReset(let durationSeconds):
            Button {
                breathingDurationSeconds = durationSeconds
                showingBreathing = true
            } label: {
                RecommendationRow(recommendation: recommendation, accent: accent)
            }
            .buttonStyle(.plain)

        case .behavioralActivation:
            NavigationLink(destination: ActivityPlannerView()) {
                RecommendationRow(recommendation: recommendation, accent: accent)
            }
            .buttonStyle(.plain)

        case .libraryExercise(let exerciseID):
            if let exercise = ExerciseService.shared.exercise(withID: exerciseID) {
                NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                    RecommendationRow(recommendation: recommendation, accent: accent)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onJournalMore()
                } label: {
                    RecommendationRow(recommendation: recommendation, accent: accent)
                }
                .buttonStyle(.plain)
            }

        case .guidedJournal:
            Button {
                onJournalMore()
            } label: {
                RecommendationRow(recommendation: recommendation, accent: accent)
            }
            .buttonStyle(.plain)

        case .introToCBT:
            NavigationLink(destination: WhatIsCBTPagerView()) {
                RecommendationRow(recommendation: recommendation, accent: accent)
            }
            .buttonStyle(.plain)

        case .thoughtRecord:
            Button {
                showingThoughtRecord = true
            } label: {
                RecommendationRow(recommendation: recommendation, accent: accent)
            }
            .buttonStyle(.plain)

        case .safetySupport:
            Button {
                openSafetySupport()
            } label: {
                RecommendationRow(recommendation: recommendation, accent: accent)
            }
            .buttonStyle(.plain)

        case .moodCheckIn, .weeklyReview, .course, .program, .assessments:
            Button {
                onSkip()
            } label: {
                RecommendationRow(recommendation: recommendation, accent: accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func openSafetySupport() {
        AchievementService.shared.recordBadDayModeUsed(in: modelContext)
        showingSafetySupport = true
    }

    private func nextStepChipSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DSTypography.sectionTitle)
                .foregroundStyle(DSTheme.primaryText)

            FlowLikeChipRow(items: items)
        }
    }

    private var breathingView: some View {
        NavigationStack {
            BreathingResetView(
                durationSeconds: breathingDurationSeconds,
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

    private func handleReminderPromptAccepted(_ moment: ReminderOptInMoment) {
        guard !isHandlingReminderPrompt else { return }
        isHandlingReminderPrompt = true
        Task {
            _ = await ReminderOptInService.shared.accept(moment, modelContext: modelContext)
            await MainActor.run {
                reminderPromptMoment = nil
                isHandlingReminderPrompt = false
            }
        }
    }

    private func handleReminderPromptDismissed(_ moment: ReminderOptInMoment) {
        ReminderOptInService.shared.dismiss(moment)
        reminderPromptMoment = nil
    }
}

private struct RecommendationRow: View {
    let recommendation: DailyRecommendation
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: recommendation.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.title)
                    .font(DSTypography.button)
                    .foregroundStyle(DSTheme.primaryText)
                    .multilineTextAlignment(.leading)

                Text(recommendation.subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSTheme.secondaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .fill(DSTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .stroke(DSTheme.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct FlowLikeChipRow: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    TagChip(title: item)
                }
            }
        }
    }
}
