import OSLog
import SwiftData
import SwiftUI

enum LibraryMetadataFilter: String, CaseIterable, Identifiable {
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
    @State private var continueItem: ContinueItem?
    @State private var selectedContinueExercise: Exercise?
    @State private var selectedContinueCourse: Course?
    @State private var showingContinueProgram = false
    @State private var showingContinueActivityPlanner = false
    @State private var showingCopingToolkit = false

    private var exercises: [Exercise] {
        ExerciseService.shared.exercises
    }

    private var libraryFilter: LibraryFilter {
        LibraryFilter(metadataFilter: selectedMetadataFilter, metadataValue: selectedMetadataValue)
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allExerciseItems: [LibraryItem] {
        libraryItems.filter { $0.format == LibraryItemType.exercise.rawValue }
    }

    private var exerciseItems: [LibraryItem] {
        allExerciseItems.filter(libraryFilter.matches(item:))
    }

    private var guidedPracticeItems: [LibraryItem] {
        libraryItems
            .filter { $0.format != LibraryItemType.exercise.rawValue }
            .filter(libraryItemIsAvailable)
            .filter(libraryFilter.matches(item:))
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
        guard !searchQuery.isEmpty else { return categoryItems }

        return categoryItems.filter { LibraryFilter.itemMatchesSearch($0, query: searchQuery) }
    }

    private var visibleGuidedPracticeItems: [LibraryItem] {
        guard !searchQuery.isEmpty else { return guidedPracticeItems }
        return guidedPracticeItems.filter { LibraryFilter.itemMatchesSearch($0, query: searchQuery) }
    }

    private func libraryItemIsAvailable(_ item: LibraryItem) -> Bool {
        guard item.type == .audio else { return true }

        let filename = persistedAudioContent(for: item)?.localAssetFilename
            ?? LibraryService.shared.audioContent(for: item)?.localAssetFilename
        guard let filename else { return false }

        return LibraryService.shared.audioAssetIsBundled(named: filename)
    }

    private var visibleCourses: [Course] {
        return courses.filter { course in
            !course.isSkillPath &&
            libraryFilter.matches(course: course) &&
            LibraryFilter.courseMatchesSearch(course, query: searchQuery)
        }
    }

    private var visibleSkillPaths: [Course] {
        return courses.filter { course in
            course.isSkillPath &&
            libraryFilter.matches(course: course) && LibraryFilter.courseMatchesSearch(course, query: searchQuery)
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
        libraryFilter.hasActiveMetadataFilter
    }

    private var shouldShowCoursesSection: Bool {
        selectedMetadataFilter != .format ||
            selectedMetadataValue == LibraryTaxonomy.allFilterLabel ||
            selectedMetadataValue == LibraryItemType.course.rawValue
    }

    private var shouldShowSkillPathsSection: Bool {
        shouldShowCoursesSection
    }

    private var shouldShowExercisesSection: Bool {
        selectedMetadataFilter != .format ||
            selectedMetadataValue == LibraryTaxonomy.allFilterLabel ||
            selectedMetadataValue == LibraryItemType.exercise.rawValue
    }

    private var shouldShowAffirmationsSection: Bool {
        libraryFilter.matchesAffirmationSection(query: searchQuery)
    }

    private var groupedExerciseItems: [(category: String, items: [LibraryItem])] {
        categories.dropFirst().map { category in
            (category, visibleExerciseItems.filter { $0.category == category })
        }
        .filter { !$0.items.isEmpty }
    }

    private var nextCourse: Course? {
        courses.first { course in
            !course.isSkillPath && !course.isCompleted && !course.orderedItems(from: libraryItems).isEmpty
        }
    }

    private var continueExerciseID: String? {
        if case .exercise(let exerciseID) = continueItem?.destination {
            return exerciseID
        }
        return nil
    }

    private var continueUpNextExercises: [Exercise] {
        let filtered = viewModel.upNextExercises.filter { $0.id != continueExerciseID }
        return Array(filtered.prefix(nextCourse == nil ? 3 : 2))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        AppScreenHeadline(title: "Tools")

                        libraryIntro

                        copingToolkitSection

                        metadataFilterControls

                        continueUpNextSection

                        behavioralActivationSection

                        recentlyCompletedSection

                        if shouldShowSkillPathsSection {
                            skillPathsSection
                        }

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
        .searchable(text: $searchText, prompt: "Search tools")
        .task {
            await seedLibrary()
            await refreshCompletions()
            refreshContinueItem()
        }
        .task(id: completions.count) {
            await viewModel.update(completions: completions, allExercises: exercises)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshCompletions()
                refreshContinueItem()
            }
        }
        .sheet(item: $selectedContinueExercise) { exercise in
            NavigationStack {
                ExerciseDetailView(exercise: exercise)
            }
            .dsSheetPresentation()
        }
        .sheet(item: $selectedContinueCourse) { course in
            NavigationStack {
                CourseDetailView(course: course, libraryItems: libraryItems)
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingContinueProgram) {
            NavigationStack {
                ProgramDetailView(program: .tacklingProcrastination)
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingContinueActivityPlanner) {
            NavigationStack {
                ActivityPlannerView()
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingCopingToolkit) {
            CopingToolkitView()
                .dsSheetPresentation()
        }
    }

    private var libraryIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercises, courses, affirmations, guided practices, and learning paths in one tools space.")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 122), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                scopePill("Skill Paths", systemImage: "map.fill")
                scopePill("Courses", systemImage: "graduationcap.fill")
                scopePill("Practices", systemImage: "figure.mind.and.body")
                scopePill("Affirmations", systemImage: "sparkles")
                scopePill("Breathing", systemImage: "wind")
                scopePill("Audio", systemImage: "headphones")
                scopePill("Toolkit", systemImage: "lifepreserver.fill")
            }
        }
    }

    private var copingToolkitSection: some View {
        Button {
            HapticManager.shared.lightImpact()
            showingCopingToolkit = true
        } label: {
            DSCardContainer {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "lifepreserver.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 44, height: 44)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Coping Toolkit")
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Fast grounding, breathing, and safety tools for harder moments.")
                            .font(DSTypography.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    SettingsDisclosureIndicator()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Coping Toolkit")
    }

    private var continueUpNextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Continue / Up Next")

            if !viewModel.isInitialized {
                loadingCard("Finding your next practice...")
            } else {
                VStack(spacing: 10) {
                    if let continueItem {
                        ContinueItemCard(item: continueItem) {
                            perform(continueItem: continueItem)
                        }
                    } else if let nextCourse {
                        NavigationLink(destination: CourseDetailView(course: nextCourse, libraryItems: libraryItems)) {
                            continueCourseRow(nextCourse)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(continueUpNextExercises) { exercise in
                        exerciseCard(exercise, showCategory: true, isComplete: false)
                    }

                    if nextCourse == nil && continueItem == nil && continueUpNextExercises.isEmpty {
                        emptyStateCard("Your next practice will appear here.", systemImage: "arrow.forward.circle")
                    }
                }
            }
        }
    }

    @MainActor
    private func refreshContinueItem() {
        let item = ContinueItemService.shared.bestItem(
            from: modelContext,
            recommendations: []
        )

        switch item?.destination {
        case .exercise, .course, .cbtPath, .activityPlanner:
            continueItem = item
        default:
            continueItem = nil
        }
    }

    private func perform(continueItem: ContinueItem) {
        switch continueItem.destination {
        case .exercise(let exerciseID):
            selectedContinueExercise = LibraryService.shared.exercise(withID: exerciseID)
        case .course(let courseID):
            selectedContinueCourse = courses.first { $0.id == courseID }
        case .cbtPath(let programID):
            if let path = courses.first(where: { $0.id == programID && $0.isSkillPath }) {
                selectedContinueCourse = path
            } else {
                showingContinueProgram = true
            }
        case .activityPlanner:
            showingContinueActivityPlanner = true
        default:
            break
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

    private var skillPathsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Skill Paths")

            VStack(spacing: 10) {
                if visibleSkillPaths.isEmpty {
                    SupportiveEmptyStateView(
                        systemImage: "map",
                        title: "Skill Paths",
                        message: skillPathsEmptyMessage,
                        actionTitle: hasActiveLibraryFilters ? "Clear Filters" : "Refresh Paths",
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

                ForEach(visibleSkillPaths) { path in
                    NavigationLink(destination: CourseDetailView(course: path, libraryItems: libraryItems)) {
                        skillPathRow(path)
                    }
                    .buttonStyle(.plain)
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
                        message: audioLibraryEmptyMessage,
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
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.selectedColor, hapticType: nil))

                Spacer()

                if hasActiveMetadataFilter {
                    Button {
                        selectedMetadataFilter = .all
                        selectedMetadataValue = LibraryTaxonomy.allFilterLabel
                        selectedCategory = LibraryTaxonomy.allFilterLabel
                        HapticManager.shared.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(DSButtonStyle(variant: .neutral, size: .icon(34), expands: false, hapticType: nil))
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
                    }
                    .buttonStyle(DSSelectionButtonStyle(isSelected: selectedMetadataValue == value, selectedColor: themeManager.selectedColor, size: .compact, expands: false))
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
                    }
                    .buttonStyle(DSSelectionButtonStyle(isSelected: selectedApproach == approach, selectedColor: themeManager.selectedColor, size: .compact, expands: false))
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
                    }
                    .buttonStyle(DSSelectionButtonStyle(isSelected: selectedCategory == category, selectedColor: themeManager.selectedColor, size: .compact, expands: false))
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
            }
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: themeManager.selectedColor, hapticType: .light))
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

    private func skillPathRow(_ path: Course) -> some View {
        let completed = path.completedLessonCount
        let total = path.progressTotal
        let actionTitle = path.isCompleted ? "Review path" : (completed == 0 ? "Start path" : "Continue")

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: path.isCompleted ? "checkmark.seal.fill" : "map.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(path.isCompleted ? Theme.successGreen : themeManager.selectedColor)
                    .frame(width: 40, height: 40)
                    .background((path.isCompleted ? Theme.successGreen : themeManager.selectedColor).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(path.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 6)

                        Text("\(path.progressPercentage)%")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(path.isCompleted ? Theme.successGreen : themeManager.selectedColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((path.isCompleted ? Theme.successGreen : themeManager.selectedColor).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(path.subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    courseMetadataRow(path, lessonCount: max(path.lessonCount, total))
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text(path.isCompleted ? "Path completed" : "\(completed) of \(total) steps")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(path.isCompleted ? Theme.successGreen : Theme.secondaryText)

                    Spacer()

                    Label(actionTitle, systemImage: "arrow.right.circle.fill")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(themeManager.selectedColor)
                }

                ProgressView(value: path.progressFraction)
                    .tint(path.isCompleted ? Theme.successGreen : themeManager.selectedColor)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func courseMetadataRow(_ course: Course, lessonCount: Int) -> some View {
        let approach = course.approaches.first ?? course.approach
        let category = course.category

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                courseMetadataPill(course.displayFormat)
                courseMetadataPill(course.approach)
                courseMetadataPill(approach)
                courseMetadataPill(category)
                courseMetadataPill(course.displayDifficulty)
                courseMetadataPill("\(lessonCount) lessons")
                courseMetadataPill("\(course.estimatedTotalDuration)m")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    courseMetadataPill(course.displayFormat)
                    courseMetadataPill(course.approach)
                    courseMetadataPill(approach)
                    courseMetadataPill(course.displayDifficulty)
                }
                HStack(spacing: 6) {
                    courseMetadataPill(category)
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

        if course.isSkillPath {
            return "map.fill"
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
        searchQuery.isEmpty && !hasActiveMetadataFilter
            ? "Refresh the library to load short CBT practices you can try one at a time."
            : "Clear the filters to find a CBT practice for the moment you want to work with."
    }

    private var coursesEmptyMessage: String {
        searchQuery.isEmpty && !hasActiveMetadataFilter
            ? "Refresh courses to load a learning path you can follow one short lesson at a time."
            : "Clear the filters to find a course for the skill you want to build next."
    }

    private var skillPathsEmptyMessage: String {
        searchQuery.isEmpty && !hasActiveMetadataFilter
            ? "Refresh paths to load a guided sequence for practicing a CBT skill over time."
            : "Clear the filters to find a guided path for your next practice focus."
    }

    private var audioLibraryEmptyMessage: String {
        hasActiveLibraryFilters
            ? "Clear the filters to find a short guided practice, breathing audio, or soundscape."
            : "Refresh the audio library to load short guided practices, breathing audio, and soundscapes."
    }

    private var hasActiveLibraryFilters: Bool {
        !searchQuery.isEmpty ||
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
        libraryFilter.matchesProcrastinationCourse(query: searchQuery)
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
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var completedSummary: SessionSummary?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
        return true
    }

    private var playerContent: AudioPlayerContent {
        AudioPlayerContent(
            id: displayContent.id,
            title: displayContent.title,
            description: displayContent.description,
            assetFilename: displayContent.localAssetFilename,
            durationSeconds: displayContent.duration * 60,
            systemImage: displayContent.type.systemImage
        )
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppScreenHeadline(title: displayContent.title)

                    audioPlayerCard
                    audioHeaderCard

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
                .dsSheetPresentation(detents: [.large])
        }
        .sheet(item: $completedSummary) { summary in
            SaveSessionView(summary: summary)
                .dsSheetPresentation()
        }
    }

    private var audioPlayerCard: some View {
        MindfulnessAudioPlayerView(
            content: playerContent,
            isUnlocked: isUnlocked,
            onRequestUnlock: {
                showingPaywall = true
            },
            onClose: {
                dismiss()
            },
            onCompleted: { completion in
                markPlaybackCompleted(completion)
            },
            onSaveCompletedSession: { completion in
                completedSummary = makeSessionSummary(from: completion)
            }
        )
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
                    Text("Details")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.secondaryText)

                    metadataPills
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    favoriteButton
                    completionButton
                }

                VStack(spacing: 10) {
                    favoriteButton
                    completionButton
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var favoriteButton: some View {
        Button {
            toggleFavorite()
        } label: {
            Label(displayContent.isFavorite ? "Favorited" : "Favorite", systemImage: displayContent.isFavorite ? "heart.fill" : "heart")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(DSSecondaryButtonStyle())
        .accessibilityLabel(displayContent.isFavorite ? "Remove from favorites" : "Add to favorites")
    }

    private var completionButton: some View {
        Button {
            toggleCompletion()
        } label: {
            Label(displayContent.isCompleted ? "Completed" : "Mark Done", systemImage: displayContent.isCompleted ? "checkmark.circle.fill" : "checkmark")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(DSSecondaryButtonStyle())
        .accessibilityLabel(displayContent.isCompleted ? "Mark audio incomplete" : "Mark audio complete")
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

    private func metadataPill(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.tertiaryBackground)
            .clipShape(Capsule())
    }

    private func markPlaybackCompleted(_ completion: AudioPlaybackCompletion) {
        guard let content = editableAudioContent() else { return }
        content.markCompleted(at: completion.endedAt)
        saveAudioState(successHaptic: false)
    }

    private func makeSessionSummary(from completion: AudioPlaybackCompletion) -> SessionSummary {
        let summaryBody = audioSessionSummaryBody()
        return SessionSummary(
            sourceKind: .audio,
            sourceID: completion.content.id,
            title: completion.content.title,
            bodyText: summaryBody,
            durationSeconds: completion.durationSeconds,
            startedAt: completion.startedAt,
            endedAt: completion.endedAt
        )
    }

    private func audioSessionSummaryBody() -> String {
        var sections = [displayContent.description]

        if !displayContent.transcript.isEmpty {
            let transcriptTitle = displayContent.type == .soundscape ? "Guidance" : "Transcript"
            sections.append("\(transcriptTitle):\n\(displayContent.transcript)")
        }

        return sections
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
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
