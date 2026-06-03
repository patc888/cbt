import SwiftData
import SwiftUI

struct WeeklyReviewView: View {
    @State private var selectedWeek: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var review: WeeklyReview?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingMoodCheckIn = false
    @State private var intentionDraft = ""
    @State private var learningDraft = ""
    @State private var valueReflectionDraft = ""
    @State private var savedIntention = ""
    @State private var savedLearning = ""
    @State private var savedValueReflection = ""
    @State private var isSavingRitual = false
    @State private var ritualSaveMessage: String?
    @State private var ritualSaveError: String?

    init(weekStart: Date = Date()) {
        _selectedWeek = State(initialValue: weekStart)
    }

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headline
                    weekNavigator

                    if isLoading {
                        loadingState
                    } else if let errorMessage {
                        errorState(errorMessage)
                    } else if let review, review.hasAnyData {
                        reviewContent(review)
                    } else if let review {
                        VStack(spacing: 12) {
                            weeklyRitualCard
                            emptyState(messages: review.lowDataMessages)
                        }
                    } else {
                        emptyState(messages: [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .hideNavigationBar()
        .onAppear {
            LocalRetentionEventStore.shared.record(
                .weeklyReportViewed,
                sourceScreen: "weekly_review",
                metadata: ["view": "review"]
            )
        }
        .sheet(isPresented: $showingMoodCheckIn) {
            MoodCheckinView()
                .dsSheetPresentation()
        }
        .onChange(of: showingMoodCheckIn) { _, isPresented in
            guard !isPresented else { return }
            Task { await refreshReview() }
        }
        .task(id: selectedWeek.timeIntervalSinceReferenceDate) {
            await refreshReview()
        }
    }

    private var headline: some View {
        TopHeadlineView(
            title: String(localized: "Weekly Review"),
            leading: {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(44), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel(String(localized: "Go back"))
            },
            trailing: {
                Button {
                    showingMoodCheckIn = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(44), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel(String(localized: "Add check-in"))
            }
        )
    }

    private var weekNavigator: some View {
        DSCardContainer {
            HStack(spacing: 12) {
                Button {
                    moveWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(40), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel(String(localized: "Previous week"))

                VStack(spacing: 4) {
                    Text(String(localized: "Week of"))
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.secondaryText.opacity(0.75))
                        .textCase(.uppercase)

                    Text(selectedWeekRangeText)
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                Button {
                    moveWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(40), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .disabled(!canMoveToNextWeek)
                .accessibilityLabel(String(localized: "Next week"))
            }
        }
    }

    private var loadingState: some View {
        DSCardContainer {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(themeManager.selectedColor)

                Text(String(localized: "Preparing weekly review..."))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func errorState(_ message: String) -> some View {
        SupportiveEmptyStateView(
            systemImage: "exclamationmark.triangle.fill",
            title: String(localized: "Could Not Load Review"),
            message: message,
            actionTitle: String(localized: "Try Again"),
            actionSystemImage: "arrow.clockwise"
        ) {
            Task { await refreshReview() }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func emptyState(messages: [String]) -> some View {
        DSCardContainer {
            VStack(spacing: 14) {
                SupportiveEmptyStateView(
                    systemImage: "sparkle.magnifyingglass",
                    title: String(localized: "Weekly Review"),
                    message: String(localized: "Start with one check-in this week. Add how you feel, intensity, and one trigger so the review has a first pattern to notice."),
                    actionTitle: String(localized: "Add Check-In"),
                    actionSystemImage: "face.smiling"
                ) {
                    showingMoodCheckIn = true
                }

                lowDataList(messages)
            }
        }
    }

    private func reviewContent(_ review: WeeklyReview) -> some View {
        VStack(spacing: 12) {
            WeeklyReviewSection(title: String(localized: "Progress Letter"), systemImage: "envelope.open") {
                Text(review.progressLetter)
                    .font(DSTypography.body)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DSCardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    DSSectionHeader(
                        title: String(localized: "Summary"),
                        subtitle: String(localized: "Generated locally from your saved app data.")
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                        reviewMetric(title: String(localized: "Check-ins"), value: "\(review.checkInCount)", icon: "face.smiling")
                        reviewMetric(title: String(localized: "Avg Mood"), value: averageText(review.averageMood, suffix: "/10"), icon: "chart.line.uptrend.xyaxis")
                        reviewMetric(title: String(localized: "Stress"), value: averageText(review.averageAnxietyStress, suffix: "/10"), icon: "gauge.with.dots.needle.67percent")
                    }
                }
            }

            weeklyRitualCard

            WeeklyReviewSection(title: String(localized: "Best Pattern Discovered"), systemImage: "sparkle.magnifyingglass") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(review.bestPatternRecap.patternText)
                        .font(DSTypography.body)
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Label(String(localized: "Recommended next action"), systemImage: "arrow.up.forward.circle.fill")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.selectedColor)

                        Text(review.bestPatternRecap.recommendedNextAction)
                            .font(DSTypography.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.selectedColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
                    }
                }
            }

            WeeklyReviewSection(title: String(localized: "Common Triggers"), systemImage: "scope") {
                frequencyList(review.mostCommonTriggers, emptyText: String(localized: "No triggers were added to this week's check-ins."))
            }

            WeeklyReviewSection(title: String(localized: "Completed Exercises"), systemImage: "checkmark.circle") {
                completionList(review.completedExercises, emptyText: String(localized: "No exercises were completed this week."))
            }

            WeeklyReviewSection(title: String(localized: "Completed Tiny Wins"), systemImage: "sparkles") {
                completionList(review.completedTinyWins, emptyText: String(localized: "No planned activities were marked complete this week."))
            }

            WeeklyReviewSection(title: String(localized: "Values Practiced"), systemImage: "star.circle") {
                completionList(review.practicedValues, emptyText: String(localized: "No value-based tiny actions were marked complete this week."))
            }

            WeeklyReviewSection(title: String(localized: "What Helped Most"), systemImage: "heart.text.square") {
                Text(review.whatHelpedMost)
                    .font(DSTypography.body)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            WeeklyReviewSection(title: String(localized: "Focus for Next Week"), systemImage: "arrow.forward.circle") {
                Text(review.suggestedFocusForNextWeek)
                    .font(DSTypography.body)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !review.lowDataMessages.isEmpty {
                DSCardContainer {
                    lowDataList(review.lowDataMessages)
                }
            }
        }
    }

    private var weeklyRitualCard: some View {
        WeeklyReviewSection(title: String(localized: "Weekly Ritual"), systemImage: "leaf") {
            VStack(alignment: .leading, spacing: 12) {
                ritualPromptField(
                    title: String(localized: "What do I want to practice this week?"),
                    placeholder: String(localized: "A small intention for the week..."),
                    text: $intentionDraft
                )

                ritualPromptField(
                    title: String(localized: "What did I learn?"),
                    placeholder: String(localized: "Something I want to remember..."),
                    text: $learningDraft
                )

                ritualPromptField(
                    title: String(localized: "Which value felt worth carrying forward?"),
                    placeholder: String(localized: "A value or small action I want to keep near..."),
                    text: $valueReflectionDraft
                )

                HStack(spacing: 10) {
                    if isSavingRitual {
                        ProgressView()
                            .tint(themeManager.selectedColor)
                    } else if let ritualSaveError {
                        Label(ritualSaveError, systemImage: "exclamationmark.triangle.fill")
                            .font(DSTypography.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let ritualSaveMessage {
                        Label(ritualSaveMessage, systemImage: "checkmark.circle.fill")
                            .font(DSTypography.caption)
                            .foregroundStyle(themeManager.selectedColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button {
                        saveWeeklyRitual()
                    } label: {
                        Label(String(localized: "Save"), systemImage: "checkmark")
                    }
                    .buttonStyle(DSButtonStyle(variant: .primary, size: .compact, expands: false, tint: themeManager.selectedColor, hapticType: .success))
                    .disabled(!hasUnsavedRitualChanges || isSavingRitual)
                }
            }
        }
    }

    private func ritualPromptField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            TextField(placeholder, text: text, axis: .vertical)
                .font(DSTypography.body)
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
    }

    private func reviewMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)

            Text(title.uppercased())
                .font(.system(.caption2, design: .rounded).weight(.black))
                .foregroundStyle(Theme.secondaryText.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .padding(12)
        .background(themeManager.selectedColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
        }
    }

    private func frequencyList(_ values: [WeeklyReviewFrequency], emptyText: String) -> AnyView {
        if values.isEmpty {
            return AnyView(Text(emptyText)
                .font(DSTypography.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true))
        } else {
            return AnyView(VStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
                    reviewRow(title: value.label, value: "\(value.count)")
                    if index < values.count - 1 {
                        Divider()
                    }
                }
            })
        }
    }

    private func completionList(_ values: [WeeklyReviewCompletion], emptyText: String) -> AnyView {
        if values.isEmpty {
            return AnyView(Text(emptyText)
                .font(DSTypography.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true))
        } else {
            return AnyView(VStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
                    reviewRow(title: value.label, value: "\(value.count)")
                    if index < values.count - 1 {
                        Divider()
                    }
                }
            })
        }
    }

    private func reviewRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(DSTypography.body)
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 8)
    }

    private func lowDataList(_ messages: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(messages, id: \.self) { message in
                Label(message, systemImage: "info.circle")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @MainActor
    private func refreshReview() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedReview = try WeeklyReviewService().generateReview(
                forWeekContaining: selectedWeek,
                from: modelContext
            )
            review = loadedReview
            applyRitualDrafts(from: loadedReview)
            FirstSevenDaysJourneyService.shared.mark(.weeklyReview, in: modelContext)
        } catch {
            review = nil
            errorMessage = "Could not load weekly review: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    private func saveWeeklyRitual() {
        isSavingRitual = true
        ritualSaveMessage = nil
        ritualSaveError = nil

        do {
            try WeeklyReviewService().saveRitual(
                forWeekContaining: selectedWeek,
                intention: intentionDraft,
                learning: learningDraft,
                valueReflection: valueReflectionDraft,
                in: modelContext
            )
            savedIntention = intentionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            savedLearning = learningDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            savedValueReflection = valueReflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            intentionDraft = savedIntention
            learningDraft = savedLearning
            valueReflectionDraft = savedValueReflection
            ritualSaveMessage = String(localized: "Saved")
            review = try WeeklyReviewService().generateReview(
                forWeekContaining: selectedWeek,
                from: modelContext
            )
            AchievementService.shared.evaluateAchievements(in: modelContext)
        } catch {
            ritualSaveError = String(localized: "Could not save")
        }

        isSavingRitual = false
    }

    private func applyRitualDrafts(from review: WeeklyReview) {
        savedIntention = review.ritualIntention
        savedLearning = review.ritualLearning
        savedValueReflection = review.ritualValueReflection
        intentionDraft = review.ritualIntention
        learningDraft = review.ritualLearning
        valueReflectionDraft = review.ritualValueReflection
        ritualSaveMessage = nil
        ritualSaveError = nil
    }

    private var hasUnsavedRitualChanges: Bool {
        intentionDraft.trimmingCharacters(in: .whitespacesAndNewlines) != savedIntention ||
            learningDraft.trimmingCharacters(in: .whitespacesAndNewlines) != savedLearning ||
            valueReflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines) != savedValueReflection
    }

    private var selectedWeekInterval: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: selectedWeek)
            ?? DateInterval(start: Calendar.current.startOfDay(for: selectedWeek), duration: 7 * 24 * 60 * 60)
    }

    private var selectedWeekRangeText: String {
        formattedRange(start: selectedWeekInterval.start, end: selectedWeekInterval.end)
    }

    private var canMoveToNextWeek: Bool {
        let currentWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Calendar.current.startOfDay(for: Date()), duration: 7 * 24 * 60 * 60)
        return selectedWeekInterval.start < currentWeek.start
    }

    private func moveWeek(by weeks: Int) {
        guard let newDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedWeek) else {
            return
        }

        selectedWeek = newDate
    }

    private func formattedRange(start: Date, end: Date) -> String {
        let inclusiveEnd = Calendar.current.date(byAdding: .second, value: -1, to: end) ?? end
        return "\(start.formatted(date: .abbreviated, time: .omitted)) - \(inclusiveEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    private func averageText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "N/A" }
        return "\(Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value))\(suffix)"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private struct WeeklyReviewSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 22)
                    Text(title)
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content()
            }
        }
    }
}
