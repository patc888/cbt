import OSLog
import SwiftData
import SwiftUI

struct CourseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var course: Course

    @Query private var settings: [UserSettings]
    @Query private var challengeSessions: [ChallengeSession]

    let libraryItems: [LibraryItem]

    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var currentIndex: Int
    @State private var finalReflectionDraft: String
    @State private var selectedJournalTemplate: JournalTemplate?
    @State private var showingPaywall = false
    @State private var showingCelebration = false

    private var lessons: [CourseLesson] {
        let courseLessons = course.lessons
        return courseLessons.isEmpty ? legacyLessons : courseLessons
    }

    private var legacyLessons: [CourseLesson] {
        course.orderedItems(from: libraryItems).map { item in
            let exercise = LibraryService.shared.exercise(for: item)
            return CourseLesson(
                id: item.id,
                title: item.title,
                shortEducationalText: exercise?.description ?? "Open the linked exercise to practice this skill.",
                keyTakeaway: exercise?.completionSummary ?? "A small, completed practice is more useful than a perfect plan.",
                reflectionPrompt: exercise?.journalReflection,
                linkedExerciseID: item.id,
                estimatedDuration: item.duration
            )
        }
    }

    private var itemsByID: [String: LibraryItem] {
        libraryItems.reduce(into: [:]) { result, item in
            result[item.id] = result[item.id] ?? item
        }
    }

    private var currentLesson: CourseLesson? {
        if let session = challengeSession {
            return session.getNextStep(from: lessons)
        }

        guard lessons.indices.contains(currentIndex) else { return lessons.first }
        return lessons[currentIndex]
    }

    private var challengeSession: ChallengeSession? {
        challengeSessions.first
    }

    private var linkedJournalTemplates: [JournalTemplate] {
        course.linkedGuidedJournalIDs.compactMap { id in
            JournalTemplate.allTemplates.first { $0.id == id }
        }
    }

    private var hasFullAccess: Bool {
        return true
    }

    private var displayLessonCount: Int {
        max(course.lessonCount, lessons.count)
    }

    init(course: Course, libraryItems: [LibraryItem]) {
        self.course = course
        self.libraryItems = libraryItems
        self._currentIndex = State(initialValue: course.progressIndex(in: libraryItems))
        self._finalReflectionDraft = State(initialValue: course.finalReflectionResponse ?? "")
        let challengeID = course.id
        self._challengeSessions = Query(filter: #Predicate<ChallengeSession> { $0.challengeID == challengeID })
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppScreenHeadline(title: course.title)

                    overviewCard
                    completionMessageCard

                    if lessons.isEmpty {
                        emptyCourseState
                    } else if hasFullAccess {
                        if let currentLesson {
                            currentLessonCard(currentLesson)
                        }

                        linkedResourcesSection
                        finalReflectionSection
                        lessonList
                    } else {
                        lockedCourseCard
                    }
                }
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 32)
            }
        }
        #if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            syncChallengeSession()
            finalReflectionDraft = course.finalReflectionResponse ?? ""
        }
        .sheet(item: $selectedJournalTemplate) { template in
            GuidedJournalWizardView(template: template)
                .dsSheetPresentation()
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
                .dsSheetPresentation(detents: [.large])
        }
        .sheet(isPresented: $showingCelebration) {
            ChallengeCelebrationModal(challengeTitle: course.title)
                .dsSheetPresentation(detents: [.medium])
        }
    }

    @ViewBuilder
    private var completionMessageCard: some View {
        let message = course.completionMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if course.isCompleted, !message.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.successGreen)
                    .padding(.top, 1)

                Text(message)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.successGreen.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
        }
    }

    private var emptyCourseState: some View {
        SupportiveEmptyStateView(
            systemImage: "graduationcap",
            title: "Course Path",
            message: "Courses gather related practices into a step-by-step path. This course is waiting for its lessons to load.",
            actionTitle: "Back to Library",
            actionSystemImage: "chevron.left"
        ) {
            HapticManager.shared.lightImpact()
            dismiss()
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: courseIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(course.isCompleted ? Theme.successGreen : themeManager.selectedColor)
                    .frame(width: 44, height: 44)
                    .background((course.isCompleted ? Theme.successGreen : themeManager.selectedColor).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    if !course.subtitle.isEmpty {
                        Text(course.subtitle)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    metadataWrap
                }
            }

            if !course.courseDescription.isEmpty {
                Text(course.courseDescription)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                HStack {
                    Text(course.isCompleted ? "Course completed" : "\(course.completedLessonCount) of \(course.progressTotal) lessons")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(course.isCompleted ? Theme.successGreen : Theme.secondaryText)
                    Spacer()
                    Text("\(Int(course.progressFraction * 100))%")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }

                ProgressView(value: course.progressFraction)
                    .tint(course.isCompleted ? Theme.successGreen : themeManager.selectedColor)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var metadataWrap: some View {
        let approach = course.approaches.first ?? course.approach
        let category = course.category

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                metadataPill(course.displayFormat)
                metadataPill(course.approach)
                metadataPill(approach)
                metadataPill(category)
                metadataPill(course.displayDifficulty)
                metadataPill("\(displayLessonCount) lessons")
                metadataPill("\(course.estimatedTotalDuration)m")
                metadataPill(course.isPremium ? "Premium" : "Free")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    metadataPill(course.displayFormat)
                    metadataPill(course.approach)
                    metadataPill(approach)
                    metadataPill(category)
                }
                HStack(spacing: 6) {
                    metadataPill(course.displayDifficulty)
                    metadataPill("\(displayLessonCount) lessons")
                    metadataPill("\(course.estimatedTotalDuration)m")
                    metadataPill(course.isPremium ? "Premium" : "Free")
                }
            }
        }
    }

    private func currentLessonCard(_ lesson: CourseLesson) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            challengeProgressHeader

            HStack {
                Text("Lesson \(currentIndex + 1)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .textCase(.uppercase)

                Spacer()

                Text("\(lesson.estimatedDuration)m")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(lesson.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(lesson.shortEducationalText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            lessonTakeaway(lesson.keyTakeaway)

            if let reflectionPrompt = lesson.reflectionPrompt, !reflectionPrompt.isEmpty {
                reflectionPromptView(reflectionPrompt)
            }

            if let item = linkedItem(for: lesson) {
                NavigationLink(destination: LibraryItemDestinationView(item: item)) {
                    actionLabel(title: "Open Exercise", systemImage: "arrow.up.right.circle.fill", filled: false)
                }
                .buttonStyle(.plain)
            }

            if course.isLessonCompleted(lesson) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Lesson complete")
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.successGreen)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.successGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Button {
                    complete(lesson)
                } label: {
                    actionLabel(title: "Mark Lesson Complete", systemImage: "checkmark", filled: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    @ViewBuilder
    private var linkedResourcesSection: some View {
        if !linkedJournalTemplates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Guided Journals")

                ForEach(linkedJournalTemplates) { template in
                    Button {
                        selectedJournalTemplate = template
                        HapticManager.shared.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: template.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(themeManager.selectedColor)
                                .frame(width: 36, height: 36)
                                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                                    .multilineTextAlignment(.leading)
                                Text(template.description)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(themeManager.selectedColor)
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var finalReflectionSection: some View {
        if course.isCompleted,
           let prompt = course.finalReflectionPrompt,
           !prompt.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Final Reflection")

                VStack(alignment: .leading, spacing: 10) {
                    Text(prompt)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $finalReflectionDraft)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 110)
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        saveFinalReflection()
                    } label: {
                        actionLabel(
                            title: course.finalReflectionResponse?.isEmpty == false ? "Update Reflection" : "Save Reflection",
                            systemImage: "square.and.arrow.down",
                            filled: true
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(finalReflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(finalReflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                }
                .padding(Theme.paddingMedium)
                .cardStyle()
            }
        }
    }

    private var lessonList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Lessons")

            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                Button {
                    currentIndex = index
                    HapticManager.shared.selection()
                } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(currentIndex == index ? .white : themeManager.selectedColor)
                            .frame(width: 28, height: 28)
                            .background(currentIndex == index ? themeManager.selectedColor : themeManager.selectedColor.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("\(lesson.estimatedDuration)m lesson")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()

                        if course.isLessonCompleted(lesson) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.successGreen)
                        }
                    }
                    .padding(12)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var challengeProgressHeader: some View {
        let total = max(lessons.count, 1)
        let completedSteps = min(challengeSession?.currentStepIndex ?? course.completedLessonCount, total)
        let fraction = Double(completedSteps) / Double(total)

        return VStack(spacing: 8) {
            HStack {
                Text((challengeSession?.isCompleted ?? course.isCompleted) ? "Challenge done" : "Step \(completedSteps + 1) of \(total)")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle((challengeSession?.isCompleted ?? course.isCompleted) ? Theme.successGreen : Theme.secondaryText)

                Spacer()

                Text("\(Int(fraction * 100))%")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }

            ProgressView(value: fraction)
                .tint((challengeSession?.isCompleted ?? course.isCompleted) ? Theme.successGreen : themeManager.selectedColor)
                .animation(.easeInOut(duration: 0.25), value: fraction)
        }
    }

    private var lockedCourseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 40, height: 40)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium Course")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("Unlock full access to start this course.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Button {
                showingPaywall = true
            } label: {
                actionLabel(title: "View Full Access", systemImage: "sparkles", filled: true)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var courseIcon: String {
        if course.isCompleted {
            return "checkmark.seal.fill"
        }

        return course.approach == "Crash Course" ? "bolt.fill" : "graduationcap.fill"
    }

    @ViewBuilder
    private func metadataPill(_ title: String) -> some View {
        if !title.isEmpty {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.tertiaryBackground)
                .clipShape(Capsule())
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryText)
    }

    private func lessonTakeaway(_ takeaway: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .padding(.top, 2)

            Text(takeaway)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.selectedColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func reflectionPromptView(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reflection Prompt")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)

            Text(prompt)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func actionLabel(title: String, systemImage: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.system(.headline, design: .rounded).weight(.bold))
        .foregroundStyle(filled ? .white : themeManager.selectedColor)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(filled ? themeManager.selectedColor : themeManager.selectedColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func linkedItem(for lesson: CourseLesson) -> LibraryItem? {
        guard let linkedExerciseID = lesson.linkedExerciseID else { return nil }
        return itemsByID[linkedExerciseID]
    }

    private func complete(_ lesson: CourseLesson) {
        let session = ensureChallengeSession()
        course.markCompleted(lesson: lesson)
        let didFinishChallenge = session.advance(totalSteps: lessons.count)
        currentIndex = min(session.currentStepIndex, max(lessons.count - 1, 0))

        if let nextIndex = lessons.firstIndex(where: { !course.isLessonCompleted($0) }) {
            currentIndex = nextIndex
        }

        do {
            try modelContext.save()
            AchievementService.shared.evaluateAchievements(in: modelContext)
            HapticManager.shared.success()
            if didFinishChallenge {
                showingCelebration = true
            }
            Task { @MainActor in
                await PersonalizedReminderService.shared.refreshEnabledReminders(modelContext: modelContext)
            }
        } catch {
            AppLogger.make(category: "Library").error("Failed to save course progress: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func ensureChallengeSession() -> ChallengeSession {
        if let challengeSession {
            return challengeSession
        }

        let session = ChallengeSession(challengeID: course.id)
        session.syncWithCompletedSteps(course.completedLessonCount, totalSteps: lessons.count)
        modelContext.insert(session)
        return session
    }

    private func syncChallengeSession() {
        let session = ensureChallengeSession()
        session.syncWithCompletedSteps(course.completedLessonCount, totalSteps: lessons.count)
        currentIndex = min(session.currentStepIndex, max(lessons.count - 1, 0))

        do {
            try modelContext.save()
        } catch {
            AppLogger.make(category: "Library").error("Failed to save challenge session: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func saveFinalReflection() {
        let trimmed = finalReflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        course.finalReflectionResponse = trimmed

        do {
            try modelContext.save()
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Library").error("Failed to save final reflection: \(error.localizedDescription, privacy: .private)")
        }
    }
}

private struct ChallengeCelebrationModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    let challengeTitle: String

    var body: some View {
        DSSheetContainer {
            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 72, height: 72)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                VStack(spacing: 8) {
                    Text("Challenge Done")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text("You finished \(challengeTitle). Take a moment to notice the follow-through.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    HapticManager.shared.lightImpact()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                        Text("Continue")
                    }
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(themeManager.selectedColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.paddingMedium)
        }
    }
}
