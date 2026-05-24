import OSLog
import SwiftData
import SwiftUI

private enum LibraryMetadataFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case approach = "Approach"
    case topic = "Topic"
    case format = "Format"
    case difficulty = "Difficulty"

    var id: String { rawValue }

    var preferredOrder: [String] {
        switch self {
        case .all:
            return []
        case .approach:
            return LibraryTaxonomy.approachOrder
        case .topic:
            return LibraryTaxonomy.topicOrder
        case .format:
            return LibraryTaxonomy.formatOrder
        case .difficulty:
            return LibraryTaxonomy.difficultyOrder
        }
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: [SortDescriptor(\LibraryItem.category), SortDescriptor(\LibraryItem.title)])
    private var libraryItems: [LibraryItem]
    @Query(sort: \Course.title)
    private var courses: [Course]
    @Query(sort: [SortDescriptor(\AudioContent.category), SortDescriptor(\AudioContent.title)])
    private var audioContents: [AudioContent]
    @Query(filter: #Predicate<ProgramProgress> { $0.programID == "tackling_procrastination" && !$0.isDeleted })
    private var programProgresses: [ProgramProgress]

    @State private var selectedCategory = "All"
    @State private var selectedApproach = "All"
    @State private var selectedMetadataFilter: LibraryMetadataFilter = .all
    @State private var selectedMetadataValue = LibraryTaxonomy.allFilterLabel
    @State private var searchText = ""
    @State private var completions: [ExerciseCompletion] = []
    @State private var viewModel = ExercisesViewModel()

    private var exercises: [Exercise] {
        ExerciseService.shared.exercises
    }

    private var allExerciseItems: [LibraryItem] {
        libraryItems.filter { $0.format == LibraryItemType.exercise.rawValue }
    }

    private var exerciseItems: [LibraryItem] {
        allExerciseItems.filter(itemMatchesSelectedMetadataFilter)
    }

    private var guidedPracticeItems: [LibraryItem] {
        libraryItems
            .filter { $0.format != LibraryItemType.exercise.rawValue }
            .filter(itemMatchesSelectedMetadataFilter)
    }

    private var behavioralActivationItems: [LibraryItem] {
        exerciseItems.filter { $0.category == "Behavioral Activation" }
    }

    private var approaches: [String] {
        [LibraryTaxonomy.allFilterLabel] + LibraryService.shared.approaches(for: allExerciseItems)
    }

    private var approachFilteredExerciseItems: [LibraryItem] {
        guard selectedApproach != LibraryTaxonomy.allFilterLabel else { return exerciseItems }
        return exerciseItems.filter {
            $0.approaches.contains { $0.caseInsensitiveCompare(selectedApproach) == .orderedSame }
        }
    }

    private var categories: [String] {
        [LibraryTaxonomy.allFilterLabel] + LibraryService.shared.categories(for: approachFilteredExerciseItems)
    }

    private var visibleExerciseItems: [LibraryItem] {
        let categoryItems = selectedCategory == LibraryTaxonomy.allFilterLabel
            ? approachFilteredExerciseItems
            : approachFilteredExerciseItems.filter { $0.category == selectedCategory }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categoryItems }

        return categoryItems.filter { itemMatchesSearch($0, query: query) }
    }

    private var visibleGuidedPracticeItems: [LibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return guidedPracticeItems }
        return guidedPracticeItems.filter { itemMatchesSearch($0, query: query) }
    }

    private var visibleCourses: [Course] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return courses.filter { course in
            courseMatchesSelectedMetadataFilter(course) && courseMatchesSearch(course, query: query)
        }
    }

    private var metadataFilterValues: [String] {
        let values: [String]

        switch selectedMetadataFilter {
        case .all:
            values = []
        case .approach:
            values = libraryItems.flatMap(\.approaches) + courses.flatMap(\.approaches)
        case .topic:
            values = libraryItems.flatMap(\.topics) + courses.flatMap(\.topics)
        case .format:
            values = libraryItems.map(\.format) + courses.map(\.displayFormat) + [LibraryItemType.affirmation.rawValue]
        case .difficulty:
            values = libraryItems.map(\.displayDifficulty) + courses.map(\.displayDifficulty)
        }

        return [LibraryTaxonomy.allFilterLabel] + LibraryTaxonomy.orderedValues(values, preferredOrder: selectedMetadataFilter.preferredOrder)
    }

    private var hasActiveMetadataFilter: Bool {
        selectedMetadataFilter != .all && selectedMetadataValue != LibraryTaxonomy.allFilterLabel
    }

    private var shouldShowCoursesSection: Bool {
        selectedMetadataFilter != .format ||
            selectedMetadataValue == LibraryTaxonomy.allFilterLabel ||
            selectedMetadataValue == LibraryItemType.course.rawValue
    }

    private var shouldShowExercisesSection: Bool {
        selectedMetadataFilter != .format ||
            selectedMetadataValue == LibraryTaxonomy.allFilterLabel ||
            selectedMetadataValue == LibraryItemType.exercise.rawValue
    }

    private var shouldShowAffirmationsSection: Bool {
        let formatMatches = selectedMetadataFilter != .format ||
            selectedMetadataValue == LibraryTaxonomy.allFilterLabel ||
            selectedMetadataValue == LibraryItemType.affirmation.rawValue
        guard formatMatches else { return false }

        guard matchesSelectedMetadataFilter(
            approaches: ["Positive Psychology", "Self-Compassion"],
            topics: ["Anxiety Tools", "Depression Support", "Sleep & Wind Down", "Stress & Burnout"],
            format: LibraryItemType.affirmation.rawValue,
            difficulty: "Beginner"
        ) else {
            return false
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let fields = [
            "Affirmation Practice",
            "Affirmations",
            "Positive Psychology",
            "Self-Compassion",
            "Anxiety Tools",
            "Depression Support",
            "Sleep & Wind Down"
        ]
        let haystack = fields.joined(separator: " ").lowercased()
        return terms(in: query).allSatisfy { haystack.contains($0) }
    }

    private var groupedExerciseItems: [(category: String, items: [LibraryItem])] {
        categories.dropFirst().map { category in
            (category, visibleExerciseItems.filter { $0.category == category })
        }
        .filter { !$0.items.isEmpty }
    }

    private var nextCourse: Course? {
        courses.first { course in
            !course.isCompleted && !course.orderedItems(from: libraryItems).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        AppScreenHeadline(title: "Exercises Library")

                        libraryIntro

                        metadataFilterControls

                        continueUpNextSection

                        behavioralActivationSection

                        recentlyCompletedSection

                        if shouldShowCoursesSection {
                            coursesSection
                        }

                        if shouldShowAffirmationsSection {
                            affirmationsSection
                        }

                        breathingShortcutsSection

                        learningToolsSection

                        audioLibrarySection

                        if approaches.count > 2 {
                            approachTabs
                        }

                        categoryTabs

                        if shouldShowExercisesSection {
                            exercisesSection
                        }
                    }
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset)
                }
            }
            #if os(iOS)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .searchable(text: $searchText, prompt: "Search library")
        .task {
            await seedLibrary()
            await refreshCompletions()
        }
        .task(id: completions.count) {
            await viewModel.update(completions: completions, allExercises: exercises)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshCompletions() }
        }
    }

    private var libraryIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercises, courses, affirmations, guided practices, and learning paths in one place.")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 122), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                scopePill("Courses", systemImage: "graduationcap.fill")
                scopePill("Exercises", systemImage: "figure.mind.and.body")
                scopePill("Affirmations", systemImage: "sparkles")
                scopePill("Breathing", systemImage: "wind")
                scopePill("Audio", systemImage: "headphones")
            }
        }
    }

    private var continueUpNextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Continue / Up Next")

            if !viewModel.isInitialized {
                loadingCard("Finding your next practice...")
            } else {
                VStack(spacing: 10) {
                    if let nextCourse {
                        NavigationLink(destination: CourseDetailView(course: nextCourse, libraryItems: libraryItems)) {
                            continueCourseRow(nextCourse)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(Array(viewModel.upNextExercises.prefix(nextCourse == nil ? 3 : 2))) { exercise in
                        exerciseCard(exercise, showCategory: true, isComplete: false)
                    }

                    if nextCourse == nil && viewModel.upNextExercises.isEmpty {
                        emptyStateCard("Your next practice will appear here.", systemImage: "arrow.forward.circle")
                    }
                }
            }
        }
    }

    private var behavioralActivationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Behavioral Activation")

            NavigationLink(destination: ActivityPlannerView()) {
                activityPlannerCard
            }
            .buttonStyle(.plain)

            if !behavioralActivationItems.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(behavioralActivationItems.prefix(2))) { item in
                        NavigationLink(destination: LibraryItemDestinationView(item: item)) {
                            libraryItemRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentlyCompletedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Recently Completed")

            if !viewModel.isInitialized {
                loadingCard("Checking recent practice...")
            } else if viewModel.recentlyCompletedExercises.isEmpty {
                emptyStateCard("Completed exercises will show here.", systemImage: "checkmark.circle")
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.recentlyCompletedExercises) { exercise in
                        exerciseCard(exercise, showCategory: true, isComplete: true)
                    }
                }
            }
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Courses")

            VStack(spacing: 10) {
                if visibleCourses.isEmpty && !showsProcrastinationCourse {
                    SupportiveEmptyStateView(
                        systemImage: "graduationcap",
                        title: "Courses",
                        message: coursesEmptyMessage,
                        actionTitle: hasActiveLibraryFilters ? "Clear Filters" : "Refresh Courses",
                        actionSystemImage: hasActiveLibraryFilters ? "xmark.circle" : "arrow.clockwise"
                    ) {
                        if hasActiveLibraryFilters {
                            clearLibraryFilters()
                        } else {
                            Task { await seedLibrary() }
                        }
                    }
                    .padding(Theme.paddingMedium)
                    .cardStyle()
                }

                ForEach(visibleCourses) { course in
                    NavigationLink(destination: CourseDetailView(course: course, libraryItems: libraryItems)) {
                        courseRow(course)
                    }
                    .buttonStyle(.plain)
                }

                if showsProcrastinationCourse {
                    procrastinationCourseRow
                }
            }
        }
    }

    private var affirmationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Affirmations")

            toolLink(
                title: "Affirmation Practice",
                subtitle: "Open a quick mindset reset.",
                systemImage: "sparkles",
                actionText: "Start"
            ) {
                AffirmationPlayerView()
            }
        }
    }

    private var breathingShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Breathing Shortcuts")

            VStack(spacing: 8) {
                breathingShortcutButton(
                    title: "1 minute",
                    subtitle: "Box Breathing",
                    durationSeconds: 60,
                    pattern: .box
                )
                breathingShortcutButton(
                    title: "2 minutes",
                    subtitle: "Box Breathing",
                    durationSeconds: 120,
                    pattern: .box
                )
                breathingShortcutButton(
                    title: "4-7-8",
                    subtitle: "Relaxing breath",
                    durationSeconds: 120,
                    pattern: .relaxing478
                )
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
    }

    private var learningToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Learning Tools")

            toolLink(
                title: "Distortion Examples",
                subtitle: "Review common patterns and balanced reframes.",
                systemImage: "brain.head.profile",
                actionText: "Learn"
            ) {
                DistortionExamplesView()
            }
        }
    }

    private var audioLibrarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Audio Library")

            VStack(spacing: 10) {
                if visibleGuidedPracticeItems.isEmpty {
                    SupportiveEmptyStateView(
                        systemImage: "headphones",
                        title: "Audio Library",
                        message: "Audio sessions offer short guided practices, breathwork, and soundscapes for calm moments.",
                        actionTitle: hasActiveLibraryFilters ? "Clear Filters" : "Refresh Audio",
                        actionSystemImage: hasActiveLibraryFilters ? "xmark.circle" : "arrow.clockwise"
                    ) {
                        if hasActiveLibraryFilters {
                            clearLibraryFilters()
                        } else {
                            Task { await seedLibrary() }
                        }
                    }
                    .padding(Theme.paddingMedium)
                    .cardStyle()
                } else {
                    ForEach(visibleGuidedPracticeItems) { item in
                        NavigationLink(destination: LibraryItemDestinationView(item: item)) {
                            libraryItemRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var metadataFilterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(LibraryMetadataFilter.allCases) { filter in
                        Button(filter.rawValue) {
                            selectedMetadataFilter = filter
                            selectedMetadataValue = LibraryTaxonomy.allFilterLabel
                            selectedCategory = LibraryTaxonomy.allFilterLabel
                            HapticManager.shared.selection()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedMetadataFilter.rawValue)
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(themeManager.selectedColor.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()

                if hasActiveMetadataFilter {
                    Button {
                        selectedMetadataFilter = .all
                        selectedMetadataValue = LibraryTaxonomy.allFilterLabel
                        selectedCategory = LibraryTaxonomy.allFilterLabel
                        HapticManager.shared.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear library filters")
                }
            }

            if selectedMetadataFilter != .all {
                metadataValueTabs
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var metadataValueTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metadataFilterValues, id: \.self) { value in
                    Button {
                        selectedMetadataValue = value
                        selectedCategory = LibraryTaxonomy.allFilterLabel
                        HapticManager.shared.selection()
                    } label: {
                        Text(value)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(selectedMetadataValue == value ? Theme.backgroundColor : Theme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedMetadataValue == value ? themeManager.selectedColor : Theme.tertiaryBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedMetadataValue == value ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var approachTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(approaches, id: \.self) { approach in
                    Button {
                        selectedApproach = approach
                        selectedCategory = "All"
                        HapticManager.shared.selection()
                    } label: {
                        Text(approach)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(selectedApproach == approach ? Theme.backgroundColor : Theme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedApproach == approach ? themeManager.selectedColor : Theme.tertiaryBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedApproach == approach ? .isSelected : [])
                    .accessibilityLabel("\(approach) approach filter")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                        HapticManager.shared.selection()
                    } label: {
                        Text(category)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(selectedCategory == category ? Theme.backgroundColor : Theme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? themeManager.selectedColor : Theme.tertiaryBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Exercises")

            if visibleExerciseItems.isEmpty {
                SupportiveEmptyStateView(
                    systemImage: "figure.mind.and.body",
                    title: "Library Exercises",
                    message: emptyLibraryMessage,
                    actionTitle: hasActiveLibraryFilters ? "Clear Filters" : "Refresh Library",
                    actionSystemImage: hasActiveLibraryFilters ? "xmark.circle" : "arrow.clockwise"
                ) {
                    if hasActiveLibraryFilters {
                        clearLibraryFilters()
                    } else {
                        Task { await seedLibrary() }
                    }
                }
                .padding(Theme.paddingMedium)
                .cardStyle()
            } else if selectedCategory == "All" {
                ForEach(groupedExerciseItems, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.category)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.top, 2)

                        VStack(spacing: 10) {
                            ForEach(group.items) { item in
                                NavigationLink(destination: LibraryItemDestinationView(item: item)) {
                                    libraryItemRow(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } else {
                ForEach(visibleExerciseItems) { item in
                    NavigationLink(destination: LibraryItemDestinationView(item: item)) {
                        libraryItemRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func scopePill(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(themeManager.selectedColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(themeManager.selectedColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private func loadingCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(themeManager.selectedColor)
            Text(message)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func emptyStateCard(_ message: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            Text(message)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func exerciseCard(_ exercise: Exercise, showCategory: Bool, isComplete: Bool) -> some View {
        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
            HStack(alignment: .top, spacing: 12) {
                iconCircle(isComplete ? "checkmark.circle.fill" : "figure.mind.and.body", color: isComplete ? Theme.successGreen : themeManager.selectedColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.leading)

                    Text(exercise.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if showCategory {
                        Text("\(exercise.displayApproach) / \(exercise.displayTopics.first ?? exercise.category) / \(exercise.displayDifficulty) / \(exercise.duration)m")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(themeManager.selectedColor)
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func toolLink<Destination: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        actionText: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                iconCircle(systemImage)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Text(actionText)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(themeManager.selectedColor)
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func breathingShortcutButton(
        title: String,
        subtitle: String,
        durationSeconds: Int,
        pattern: BreathingPattern
    ) -> some View {
        Button {
            BreathingPresenter.shared.present(
                durationSeconds: durationSeconds,
                autoStart: true,
                pattern: pattern
            )
        } label: {
            HStack(spacing: 10) {
                iconCircle("wind")

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(themeManager.selectedColor)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Theme.toggleBackgroundColor(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func iconCircle(_ systemImage: String, color: Color? = nil) -> some View {
        let tint = color ?? themeManager.selectedColor
        return Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.12), in: Circle())
    }

    private var activityPlannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconCircle("calendar.badge.clock")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Planner")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("Schedule nourishing tasks and compare predicted vs. actual enjoyment.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(themeManager.selectedColor)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var procrastinationCourseRow: some View {
        let completedDays = min(max(programProgresses.first?.completedDays ?? 0, 0), 3)
        let progress = Double(completedDays) / 3.0
        let isComplete = completedDays >= 3

        return NavigationLink(destination: ProgramDetailView(program: .tacklingProcrastination)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    iconCircle("bolt.heart.fill")

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Tackling Procrastination")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 6)

                            Text("3-Day Course")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.selectedColor.opacity(0.1))
                                .foregroundStyle(themeManager.selectedColor)
                                .clipShape(Capsule())
                        }

                        Text("Overcome avoidance, practice emotion regulation, and build momentum.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                VStack(spacing: 8) {
                    HStack {
                        Text(isComplete ? "Course completed" : "Progress: Day \(completedDays) of 3")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(isComplete ? Theme.successGreen : Theme.secondaryText)
                        Spacer()
                        Text(isComplete ? "Review" : (completedDays == 0 ? "Start" : "Continue Day \(completedDays + 1)"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.selectedColor)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.trackBackgroundColor(for: colorScheme))
                                .frame(height: 6)
                            Capsule()
                                .fill(isComplete ? Theme.successGreen : themeManager.selectedColor)
                                .frame(width: geo.size.width * CGFloat(progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func courseRow(_ course: Course) -> some View {
        let total = course.progressTotal
        let completed = course.completedLessonCount
        let lessonCount = max(course.lessonCount, total)
        let progress = course.progressFraction

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: courseIcon(for: course))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(course.isCompleted ? Theme.successGreen : themeManager.selectedColor)
                    .frame(width: 38, height: 38)
                    .background((course.isCompleted ? Theme.successGreen : themeManager.selectedColor).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(course.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 6)

                        Text(course.isPremium ? "Premium" : "Free")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(course.isPremium ? themeManager.selectedColor : Theme.successGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((course.isPremium ? themeManager.selectedColor : Theme.successGreen).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if !course.subtitle.isEmpty {
                        Text(course.subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    courseMetadataRow(course, lessonCount: lessonCount)
                }
            }

            VStack(spacing: 7) {
                HStack {
                    Text(course.isCompleted ? "Completed" : "\(completed) of \(total) lessons")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(course.isCompleted ? Theme.successGreen : Theme.secondaryText)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }

                ProgressView(value: progress)
                    .tint(course.isCompleted ? Theme.successGreen : themeManager.selectedColor)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func continueCourseRow(_ course: Course) -> some View {
        let orderedItems = course.orderedItems(from: libraryItems)
        let currentIndex = course.progressIndex(in: libraryItems)
        let currentItem = orderedItems.indices.contains(currentIndex) ? orderedItems[currentIndex] : orderedItems.first
        let currentLesson = course.lessons.first { !course.completedItemIDs.contains($0.completionID) } ?? course.lessons.first
        let total = max(course.progressTotal, orderedItems.count)
        let completed = course.completedLessonCount
        let progress = course.progressFraction
        let actionTitle = completed == 0 ? "Start course" : "Continue course"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                iconCircle(courseIcon(for: course))

                VStack(alignment: .leading, spacing: 4) {
                    Text(actionTitle)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(themeManager.selectedColor)
                    Text(course.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.leading)
                    if let currentLesson {
                        Text("Next: \(currentLesson.title)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.leading)
                    } else if let currentItem {
                        Text("Next: \(currentItem.title)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(themeManager.selectedColor)
            }

            if total > 0 {
                ProgressView(value: progress)
                    .tint(themeManager.selectedColor)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func courseMetadataRow(_ course: Course, lessonCount: Int) -> some View {
        let approach = course.approaches.first ?? course.approach
        let topic = course.topics.first ?? course.category

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                courseMetadataPill(course.displayFormat)
                courseMetadataPill(approach)
                courseMetadataPill(topic)
                courseMetadataPill(course.displayDifficulty)
                courseMetadataPill("\(lessonCount) lessons")
                courseMetadataPill("\(course.estimatedTotalDuration)m")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    courseMetadataPill(course.displayFormat)
                    courseMetadataPill(approach)
                    courseMetadataPill(course.displayDifficulty)
                }
                HStack(spacing: 6) {
                    courseMetadataPill(topic)
                    courseMetadataPill("\(lessonCount) lessons")
                    courseMetadataPill("\(course.estimatedTotalDuration)m")
                }
            }
        }
    }

    @ViewBuilder
    private func courseMetadataPill(_ title: String) -> some View {
        if !title.isEmpty {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.tertiaryBackground)
                .clipShape(Capsule())
        }
    }

    private func courseIcon(for course: Course) -> String {
        if course.isCompleted {
            return "checkmark.seal.fill"
        }

        return course.approach == "Crash Course" ? "bolt.fill" : "graduationcap.fill"
    }

    private func libraryItemRow(_ item: LibraryItem) -> some View {
        let audioContent = persistedAudioContent(for: item)
        let audioSeed = LibraryService.shared.audioContent(for: item)
        let iconName = audioContent?.type.systemImage ?? audioSeed?.type.systemImage ?? LibraryItemType.systemImage(for: item.format)
        let primaryApproach = item.approaches.first
        let primaryTopic = item.topics.first

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 36, height: 36)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.leading)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Text(item.format)
                        if let primaryApproach { Text(primaryApproach) }
                        if let primaryTopic { Text(primaryTopic) }
                        Text(item.displayDifficulty)
                        if let audioType = audioContent?.type.displayName ?? audioSeed?.type.displayName {
                            Text(audioType)
                        }
                        Text("\(item.duration)m")
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.format)
                        if let primaryApproach { Text(primaryApproach) }
                        if let primaryTopic { Text(primaryTopic) }
                        Text(item.displayDifficulty)
                        if let audioType = audioContent?.type.displayName ?? audioSeed?.type.displayName {
                            Text(audioType)
                        }
                        Text("\(item.duration)m")
                    }
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)

                audioStatusRow(audioContent: audioContent, audioSeed: audioSeed)
            }

            Spacer()
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(.title3))
                .foregroundStyle(themeManager.selectedColor)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func persistedAudioContent(for item: LibraryItem) -> AudioContent? {
        guard item.type == .audio else { return nil }
        return audioContents.first { $0.id == item.id }
    }

    @ViewBuilder
    private func audioStatusRow(audioContent: AudioContent?, audioSeed: AudioContentSeed?) -> some View {
        if audioContent?.isCompleted == true || audioContent?.isFavorite == true || audioSeed?.isPremium == true {
            HStack(spacing: 6) {
                if audioContent?.isCompleted == true {
                    audioStatusPill("Done", systemImage: "checkmark.circle.fill", color: Theme.successGreen)
                }
                if audioContent?.isFavorite == true {
                    audioStatusPill("Favorite", systemImage: "heart.fill", color: .pink)
                }
                if audioSeed?.isPremium == true {
                    audioStatusPill("Premium", systemImage: "lock.fill", color: themeManager.selectedColor)
                }
            }
            .padding(.top, 2)
        }
    }

    private func audioStatusPill(_ title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var emptyLibraryMessage: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasActiveMetadataFilter
            ? "Exercises are short CBT and self-help practices you can use one at a time. The library can be refreshed if they have not loaded yet."
            : "Exercises are short CBT and self-help practices. The current filters are hiding them."
    }

    private var coursesEmptyMessage: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasActiveMetadataFilter
            ? "Courses collect related CBT and self-help practices into a simple learning path. The library can be refreshed if they have not loaded yet."
            : "Courses collect related practices into a learning path. The current filters are hiding them."
    }

    private var hasActiveLibraryFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        hasActiveMetadataFilter ||
        selectedApproach != LibraryTaxonomy.allFilterLabel ||
        selectedCategory != LibraryTaxonomy.allFilterLabel
    }

    private func clearLibraryFilters() {
        HapticManager.shared.lightImpact()
        searchText = ""
        selectedMetadataFilter = .all
        selectedMetadataValue = LibraryTaxonomy.allFilterLabel
        selectedApproach = LibraryTaxonomy.allFilterLabel
        selectedCategory = LibraryTaxonomy.allFilterLabel
    }

    private var showsProcrastinationCourse: Bool {
        guard matchesSelectedMetadataFilter(
            approaches: ["Behavioral Activation", "CBT"],
            topics: ["Productivity / Procrastination", "Depression Support"],
            format: LibraryItemType.course.rawValue,
            difficulty: "Beginner"
        ) else {
            return false
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let fields = [
            "Tackling Procrastination",
            "Productivity / Procrastination",
            "Behavioral Activation",
            "CBT",
            "Course",
            "Beginner",
            "avoidance emotion regulation momentum"
        ]
        return terms(in: query).allSatisfy { fields.joined(separator: " ").lowercased().contains($0) }
    }

    private func itemMatchesSelectedMetadataFilter(_ item: LibraryItem) -> Bool {
        matchesSelectedMetadataFilter(
            approaches: item.approaches,
            topics: item.topics,
            format: item.format,
            difficulty: item.displayDifficulty
        )
    }

    private func courseMatchesSelectedMetadataFilter(_ course: Course) -> Bool {
        matchesSelectedMetadataFilter(
            approaches: course.approaches,
            topics: course.topics,
            format: course.displayFormat,
            difficulty: course.displayDifficulty
        )
    }

    private func matchesSelectedMetadataFilter(
        approaches: [String],
        topics: [String],
        format: String,
        difficulty: String
    ) -> Bool {
        guard hasActiveMetadataFilter else { return true }

        switch selectedMetadataFilter {
        case .all:
            return true
        case .approach:
            return approaches.contains { $0.caseInsensitiveCompare(selectedMetadataValue) == .orderedSame }
        case .topic:
            return topics.contains { $0.caseInsensitiveCompare(selectedMetadataValue) == .orderedSame }
        case .format:
            return format.caseInsensitiveCompare(selectedMetadataValue) == .orderedSame
        case .difficulty:
            return difficulty.caseInsensitiveCompare(selectedMetadataValue) == .orderedSame
        }
    }

    private func itemMatchesSearch(_ item: LibraryItem, query: String) -> Bool {
        let terms = terms(in: query)

        guard !terms.isEmpty else { return true }

        var fields = [
            item.title,
            item.category,
            item.format,
            item.displayDifficulty,
            "\(item.duration) minutes"
        ]
        fields.append(contentsOf: item.approaches)
        fields.append(contentsOf: item.topics)

        if let exercise = LibraryService.shared.exercise(for: item) {
            fields.append(exercise.description)
            fields.append(contentsOf: exercise.steps)
            fields.append(contentsOf: exercise.displayApproaches)
            fields.append(contentsOf: exercise.displayTopics)
            fields.append(exercise.displayDifficulty)
            fields.append(exercise.displayFormat)
            fields.appendIfPresent(exercise.completionSummary)
            fields.appendIfPresent(exercise.journalReflection)
            fields.append(contentsOf: exercise.tags ?? [])
        }

        if let audioContent = LibraryService.shared.audioContent(for: item) {
            fields.append(audioContent.description)
            fields.append(audioContent.type.displayName)
            fields.append(audioContent.localAssetFilename)
            fields.append(audioContent.transcript)
            fields.append(audioContent.isPremium ? "premium" : "free")
        }

        let haystack = fields.joined(separator: " ").lowercased()
        return terms.allSatisfy { haystack.contains($0) }
    }

    private func courseMatchesSearch(_ course: Course, query: String) -> Bool {
        let terms = terms(in: query)
        guard !terms.isEmpty else { return true }

        var fields = [
            course.title,
            course.subtitle,
            course.courseDescription,
            course.approach,
            course.category,
            course.displayFormat,
            course.displayDifficulty,
            "\(course.estimatedTotalDuration) minutes"
        ]
        fields.append(contentsOf: course.approaches)
        fields.append(contentsOf: course.topics)
        fields.append(contentsOf: course.lessons.flatMap { lesson in
            [
                lesson.title,
                lesson.shortEducationalText,
                lesson.keyTakeaway,
                lesson.reflectionPrompt ?? ""
            ]
        })

        let haystack = fields.joined(separator: " ").lowercased()
        return terms.allSatisfy { haystack.contains($0) }
    }

    private func terms(in query: String) -> [String] {
        query
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryText)
    }

    @MainActor
    private func seedLibrary() async {
        do {
            try LibraryService.shared.seedLibraryIfNeeded(in: modelContext)
        } catch {
            AppLogger.make(category: "Library").error("Failed to seed library: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    private func refreshCompletions() async {
        completions = LaunchSafeFetch.exerciseCompletions(from: modelContext)
    }
}

private extension Array where Element == String {
    mutating func appendIfPresent(_ value: String?) {
        guard let value, !value.isEmpty else { return }
        append(value)
    }
}

struct LibraryItemDestinationView: View {
    let item: LibraryItem

    var body: some View {
        switch item.type {
        case .exercise:
            if let exercise = LibraryService.shared.exercise(for: item) {
                ExerciseDetailView(exercise: exercise)
            } else {
                missingContent
            }
        case .article:
            LibraryArticleView(item: item)
        case .affirmation:
            AffirmationPlayerView()
        case .audio:
            LibraryAudioView(item: item)
        case .course:
            missingContent
        case .journalPrompt:
            LibraryArticleView(item: item)
        }
    }

    private var missingContent: some View {
        ContentUnavailableView("Item unavailable", systemImage: "exclamationmark.triangle")
    }
}

private struct LibraryArticleView: View {
    let item: LibraryItem

    private var bodyText: String {
        String(data: item.contentData, encoding: .utf8) ?? ""
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppScreenHeadline(title: item.title)
                    Text(bodyText)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineSpacing(4)
                        .padding(Theme.paddingMedium)
                        .cardStyle()
                }
                .responsiveMaxWidth()
                .padding(.horizontal)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 16)
            }
        }
    }
}

private struct AudioContentDisplay {
    let id: String
    let title: String
    let description: String
    let category: String
    let duration: Int
    let type: AudioContentType
    let localAssetFilename: String
    let transcript: String
    let isPremium: Bool
    let isCompleted: Bool
    let completedAt: Date?
    let isFavorite: Bool

    init(audioContent: AudioContent) {
        self.id = audioContent.id
        self.title = audioContent.title
        self.description = audioContent.description
        self.category = audioContent.category
        self.duration = audioContent.duration
        self.type = audioContent.type
        self.localAssetFilename = audioContent.localAssetFilename
        self.transcript = audioContent.transcript
        self.isPremium = audioContent.isPremium
        self.isCompleted = audioContent.isCompleted
        self.completedAt = audioContent.completedAt
        self.isFavorite = audioContent.isFavorite
    }

    init(seed: AudioContentSeed) {
        self.id = seed.id
        self.title = seed.title
        self.description = seed.description
        self.category = seed.category
        self.duration = seed.duration
        self.type = seed.type
        self.localAssetFilename = seed.localAssetFilename
        self.transcript = seed.transcript
        self.isPremium = seed.isPremium
        self.isCompleted = false
        self.completedAt = nil
        self.isFavorite = false
    }

    init(item: LibraryItem) {
        self.id = item.id
        self.title = item.title
        self.description = ""
        self.category = item.category
        self.duration = item.duration
        self.type = .meditation
        self.localAssetFilename = String(data: item.contentData, encoding: .utf8) ?? item.id
        self.transcript = ""
        self.isPremium = false
        self.isCompleted = false
        self.completedAt = nil
        self.isFavorite = false
    }
}

private struct LibraryAudioView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @Query(sort: \AudioContent.title)
    private var audioContents: [AudioContent]
    @Query private var settings: [UserSettings]

    let item: LibraryItem

    private var storedAudioContent: AudioContent? {
        audioContents.first { $0.id == item.id }
    }

    private var displayContent: AudioContentDisplay {
        if let storedAudioContent {
            return AudioContentDisplay(audioContent: storedAudioContent)
        }

        if let seed = LibraryService.shared.audioContent(for: item) {
            return AudioContentDisplay(seed: seed)
        }

        return AudioContentDisplay(item: item)
    }

    private var isUnlocked: Bool {
        !displayContent.isPremium || subscriptionManager.isPremium || (settings.first?.isPremium ?? false)
    }

    private var isCurrentAudioPlaying: Bool {
        audioPlayer.isPlayingAsset(named: displayContent.localAssetFilename)
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppScreenHeadline(title: displayContent.title)

                    audioHeaderCard
                    playbackCard

                    if !displayContent.transcript.isEmpty {
                        transcriptCard
                    }

                    Spacer(minLength: 0)
                }
                .responsiveMaxWidth()
                .padding(.horizontal)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 16)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }

    private var audioHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: displayContent.type.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 44, height: 44)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayContent.description)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    metadataPills
                }
            }

            HStack(spacing: 10) {
                Button {
                    toggleFavorite()
                } label: {
                    Label(displayContent.isFavorite ? "Favorited" : "Favorite", systemImage: displayContent.isFavorite ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .accessibilityLabel(displayContent.isFavorite ? "Remove from favorites" : "Add to favorites")

                Button {
                    toggleCompletion()
                } label: {
                    Label(displayContent.isCompleted ? "Completed" : "Mark Done", systemImage: displayContent.isCompleted ? "checkmark.circle.fill" : "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .accessibilityLabel(displayContent.isCompleted ? "Mark audio incomplete" : "Mark audio complete")
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var playbackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Asset")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)

                    Text(displayContent.localAssetFilename)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                if displayContent.isPremium {
                    Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(isUnlocked ? Theme.successGreen : themeManager.selectedColor)
                        .accessibilityHidden(true)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    playPauseButton
                    stopButton
                }

                VStack(spacing: 10) {
                    playPauseButton
                    stopButton
                }
            }

            if let errorMessage = audioPlayer.errorMessage {
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(displayContent.type == .soundscape ? "Guidance" : "Transcript")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)

            Text(displayContent.transcript)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var metadataPills: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                metadataPill(displayContent.type.displayName)
                metadataPill(displayContent.category)
                metadataPill("\(displayContent.duration)m")
                metadataPill(displayContent.isPremium ? "Premium" : "Free")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    metadataPill(displayContent.type.displayName)
                    metadataPill(displayContent.category)
                }
                HStack(spacing: 6) {
                    metadataPill("\(displayContent.duration)m")
                    metadataPill(displayContent.isPremium ? "Premium" : "Free")
                }
            }
        }
    }

    private var playPauseButton: some View {
        Button {
            handlePlayPause()
        } label: {
            Label(isCurrentAudioPlaying ? "Pause" : (isUnlocked ? "Play" : "Unlock"), systemImage: isCurrentAudioPlaying ? "pause.fill" : (isUnlocked ? "play.fill" : "lock.fill"))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(themeManager.selectedColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCurrentAudioPlaying ? "Pause audio" : (isUnlocked ? "Play audio" : "Unlock premium audio"))
    }

    private var stopButton: some View {
        Button {
            audioPlayer.stop()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 52, height: 48)
                .background(Theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentAudioPlaying)
        .opacity(isCurrentAudioPlaying ? 1 : 0.55)
        .accessibilityLabel("Stop audio")
    }

    private func metadataPill(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.tertiaryBackground)
            .clipShape(Capsule())
    }

    private func handlePlayPause() {
        if !isUnlocked {
            HapticManager.shared.warning()
            showingPaywall = true
            return
        }

        if isCurrentAudioPlaying {
            audioPlayer.pause()
        } else {
            audioPlayer.playLocalAsset(
                named: displayContent.localAssetFilename,
                loop: displayContent.type == .soundscape
            )
        }
    }

    private func toggleFavorite() {
        guard let content = editableAudioContent() else { return }
        content.toggleFavorite()
        saveAudioState(successHaptic: false)
        HapticManager.shared.selection()
    }

    private func toggleCompletion() {
        guard let content = editableAudioContent() else { return }

        if content.isCompleted {
            content.resetCompletion()
            saveAudioState(successHaptic: false)
            HapticManager.shared.lightImpact()
        } else {
            content.markCompleted()
            saveAudioState(successHaptic: true)
        }
    }

    private func editableAudioContent() -> AudioContent? {
        if let storedAudioContent {
            return storedAudioContent
        }

        guard let seed = LibraryService.shared.audioContent(for: item) else {
            return nil
        }

        let newContent = AudioContent(seed: seed)
        modelContext.insert(newContent)
        return newContent
    }

    private func saveAudioState(successHaptic: Bool) {
        do {
            try modelContext.save()
            if successHaptic {
                HapticManager.shared.success()
            }
        } catch {
            AppLogger.make(category: "Library").error("Failed to save audio state: \(error.localizedDescription, privacy: .private)")
            HapticManager.shared.error()
        }
    }
}
