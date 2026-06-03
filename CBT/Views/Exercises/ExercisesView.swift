import SwiftUI
import SwiftData

struct ExercisesView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                DeferredRenderView {
                    VStack(alignment: .leading, spacing: 12) {
                        AppScreenHeadline(title: "Exercises")

                        ExercisesSkeleton()
                            .padding(.horizontal)

                        Spacer()
                    }
                    .padding(.top, 16)
                } content: {
                    ExercisesDashboardContent()
                }
            }
#if os(iOS)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
#endif
        }
    }
}

private struct ExercisesDashboardContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var completions: [ExerciseCompletion] = []
    @State private var continueItem: ContinueItem?
    @State private var selectedContinueExercise: Exercise?
    @State private var showingContinueProgram = false
    @State private var showingContinueActivityPlanner = false

    @Query(filter: #Predicate<ProgramProgress> { $0.programID == "tackling_procrastination" && !$0.isDeleted })
    private var programProgresses: [ProgramProgress]

    private let exerciseService = ExerciseService.shared
    @State private var viewModel = ExercisesViewModel()
    @State private var selectedApproach: String = "All"
    @State private var selectedCategory: String = "All"

    init() {}

    private var exercises: [Exercise] {
        exerciseService.exercises
    }

    private var categories: [String] {
        approachFilteredExercises.reduce(into: [String]()) { result, exercise in
            if !result.contains(exercise.category) {
                result.append(exercise.category)
            }
        }
    }

    private var approaches: [String] {
        exerciseService.approaches()
    }

    private var approachFilters: [String] {
        ["All"] + approaches
    }

    private var categoryFilters: [String] {
        ["All"] + categories
    }

    private var approachFilteredExercises: [Exercise] {
        if selectedApproach == "All" { return exercises }
        return exercises.filter { $0.displayApproaches.contains(selectedApproach) }
    }

    private var filteredExercises: [Exercise] {
        if selectedCategory == "All" { return approachFilteredExercises }
        return approachFilteredExercises.filter { $0.category == selectedCategory }
    }

    private var groupedExercises: [(category: String, exercises: [Exercise])] {
        if selectedCategory == "All" {
            return categories.map { category in
                let items = filteredExercises.filter { $0.category == category }
                return (category: category, exercises: items)
            }
        }
        return [(category: selectedCategory, exercises: filteredExercises)]
    }

    private var continueExerciseID: String? {
        if case .exercise(let exerciseID) = continueItem?.destination {
            return exerciseID
        }
        return nil
    }

    private var visibleUpNextExercises: [Exercise] {
        viewModel.upNextExercises.filter { $0.id != continueExerciseID }
    }

    private var exposureLadderExercise: Exercise? {
        exerciseService.exercise(withID: "exercise_exposure_ladder")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AppScreenHeadline(title: "Exercises")

                    if let continueItem {
                        ContinueItemCard(item: continueItem) {
                            perform(continueItem: continueItem)
                        }
                    }

                    quickToolsSection

                    if exercises.isEmpty {
                        Text("No exercises available.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                    } else if !viewModel.isInitialized {
                        ExercisesSkeleton()
                    } else {
                        if !visibleUpNextExercises.isEmpty {
                            sectionTitle("Up Next")
                            VStack(spacing: 10) {
                                ForEach(visibleUpNextExercises) { exercise in
                                    exerciseCard(exercise, showCategory: true, isComplete: false)
                                }
                            }
                        }

                        if !viewModel.recentlyCompletedExercises.isEmpty {
                            sectionTitle("Recently Completed")
                            VStack(spacing: 10) {
                                ForEach(viewModel.recentlyCompletedExercises) { exercise in
                                    exerciseCard(exercise, showCategory: true, isComplete: true)
                                }
                            }
                        }

                        filterChips(title: "Approach", items: approachFilters, chip: approachChip)
                        filterChips(title: "Category", items: categoryFilters, chip: categoryChip)

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(groupedExercises, id: \.category) { group in
                                if !group.exercises.isEmpty {
                                    Text(group.category)
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundStyle(Theme.primaryText)
                                        .padding(.top, 2)

                                    VStack(spacing: 10) {
                                        ForEach(group.exercises) { exercise in
                                            exerciseCard(
                                                exercise,
                                                showCategory: selectedCategory != "All",
                                                isComplete: viewModel.completionIDs.contains(exercise.id)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        if selectedApproach == "All" && selectedCategory == "All" {
                            personalGrowthCoursesSection
                        }
                    }

                    Spacer(minLength: 8)
                }
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
        }
        .task(id: completions.count) {
            await viewModel.update(completions: completions, allExercises: exercises)
        }
        .task {
            await refreshCompletions()
            refreshContinueItem()
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
    }

    @MainActor
    private func refreshCompletions() async {
        completions = LaunchSafeFetch.exerciseCompletions(from: modelContext)
    }

    @MainActor
    private func refreshContinueItem() {
        let item = ContinueItemService.shared.bestItem(
            from: modelContext,
            recommendations: []
        )

        switch item?.destination {
        case .exercise, .cbtPath, .activityPlanner:
            continueItem = item
        default:
            continueItem = nil
        }
    }

    private func perform(continueItem: ContinueItem) {
        switch continueItem.destination {
        case .exercise(let exerciseID):
            selectedContinueExercise = LibraryService.shared.exercise(withID: exerciseID)
        case .cbtPath:
            showingContinueProgram = true
        case .activityPlanner:
            showingContinueActivityPlanner = true
        default:
            break
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryText)
            .tracking(0.6)
    }

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Behavioral Activation")

            NavigationLink(destination: ActivityPlannerView()) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Activity Planner")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                            Text("Schedule 'nourishing' tasks to boost mood")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 24))
                            .foregroundStyle(themeManager.selectedColor)
                    }

                    HStack {
                        Image(systemName: "arrow.up.right.circle.fill")
                        Text("Rate Predicted vs. Actual Enjoyment")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(themeManager.selectedColor)
                }
                .padding(Theme.paddingMedium)
                .cardStyle()
            }
            .buttonStyle(.plain)

            if let exposureLadderExercise {
                NavigationLink(destination: ExerciseDetailView(exercise: exposureLadderExercise)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exposure Ladder")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                                Text("Prediction -> tiny experiment -> outcome -> learning")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 24))
                                .foregroundStyle(themeManager.selectedColor)
                        }

                        HStack {
                            Image(systemName: "list.number")
                            Text("Build confidence one small approach step at a time")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                        }
                        .foregroundStyle(themeManager.selectedColor)
                    }
                    .padding(Theme.paddingMedium)
                    .cardStyle()
                }
                .buttonStyle(.plain)
            }

            sectionTitle("Quick Tools & Mindset")

            VStack(spacing: 8) {
                NavigationLink(destination: AffirmationPlayerView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(themeManager.selectedColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Affirmations")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text("A quick mindset reset")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Theme.toggleBackgroundColor(for: .light))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                NavigationLink(destination: DistortionExamplesView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(themeManager.selectedColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distortion Examples")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text("See examples and balanced reframes")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Theme.toggleBackgroundColor(for: .light))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SafetyPlanView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "lifepreserver.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(themeManager.selectedColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rough Patch Plan")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text("Private steps and support options")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Theme.toggleBackgroundColor(for: .light))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                quickToolButton(title: "Breathing Reset (1 min)", durationSeconds: 60)
                quickToolButton(title: "Breathing Reset (2 min)", durationSeconds: 120)
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
    }

    private var personalGrowthCoursesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Personal Growth Courses")

            NavigationLink(destination: ProgramDetailView(program: .tacklingProcrastination)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.selectedColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(themeManager.selectedColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Tackling Procrastination")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                                Spacer()
                                Text("3-Day Course")
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeManager.selectedColor.opacity(0.1))
                                    .foregroundStyle(themeManager.selectedColor)
                                    .clipShape(Capsule())
                            }

                            Text("Overcome avoidance, master emotion regulation, and build momentum.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    let completedDays = programProgresses.first?.completedDays ?? 0

                    VStack(spacing: 8) {
                        HStack {
                            Text(completedDays == 3 ? "Course Completed!" : "Progress: Day \(completedDays) of 3")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(completedDays == 3 ? Theme.successGreen : Theme.secondaryText)
                            Spacer()
                            if completedDays == 3 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.successGreen)
                            } else {
                                Text("\(Int(Double(completedDays) / 3.0 * 100))%")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.trackBackgroundColor(for: colorScheme))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(completedDays == 3 ? Theme.successGreen : themeManager.selectedColor)
                                    .frame(width: geo.size.width * CGFloat(completedDays) / 3.0, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.top, 4)

                    HStack {
                        if completedDays == 3 {
                            Text("Review Syllabus")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(themeManager.selectedColor)
                        } else {
                            Text(completedDays == 0 ? "Start Course" : "Continue Day \(completedDays + 1)")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(themeManager.selectedColor)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(.title3))
                            .foregroundStyle(themeManager.selectedColor)
                    }
                    .padding(.top, 4)
                }
                .padding(Theme.paddingMedium)
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private func quickToolButton(title: String, durationSeconds: Int) -> some View {
        Button {
            BreathingPresenter.shared.present(durationSeconds: durationSeconds, autoStart: true)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wind")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.forward.square")
            }
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: themeManager.selectedColor, hapticType: .light))
    }

    private func categoryChip(_ category: String) -> some View {
        Button {
            selectedCategory = category
            HapticManager.shared.lightImpact()
        } label: {
                Text(category)
            }
            .buttonStyle(DSSelectionButtonStyle(isSelected: selectedCategory == category, selectedColor: themeManager.selectedColor, size: .compact, expands: false))
            .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
            .accessibilityLabel("\(category) category filter")
    }

    private func approachChip(_ approach: String) -> some View {
        Button {
            selectedApproach = approach
            selectedCategory = "All"
            HapticManager.shared.lightImpact()
        } label: {
            Text(approach)
        }
        .buttonStyle(DSSelectionButtonStyle(isSelected: selectedApproach == approach, selectedColor: themeManager.selectedColor, size: .compact, expands: false))
        .accessibilityAddTraits(selectedApproach == approach ? .isSelected : [])
        .accessibilityLabel("\(approach) approach filter")
    }

    private func filterChips<Chip: View>(
        title: String,
        items: [String],
        chip: @escaping (String) -> Chip
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        chip(item)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func exerciseCard(_ exercise: Exercise, showCategory: Bool, isComplete: Bool) -> some View {
        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .multilineTextAlignment(.leading)

                        if showCategory {
                            Text("\(exercise.displayApproach) - \(exercise.category)")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Spacer()
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.successGreen)
                    }
                }

                Text(exercise.description)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(.caption, weight: .bold))
                    Text("\(exercise.steps.count) steps")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                    Spacer()
                    Image(systemName: "timer")
                        .font(.system(.caption))
                    Text("\(exercise.duration)m")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(.title3))
                        .foregroundStyle(themeManager.selectedColor)
                }
                .foregroundStyle(Theme.secondaryText)
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { HapticManager.shared.selection() })
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.title). \(exercise.description). \(exercise.steps.count) steps, \(exercise.duration) minutes.")
        .accessibilityHint("Tap to start exercise")
    }
}

private struct ExercisesSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 120)
            }
        }
    }
}
