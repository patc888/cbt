import SwiftUI
import SwiftData

struct ExercisesView: View {
    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse)
    private var completions: [ExerciseCompletion]

    @State private var exercises: [Exercise] = []
    @State private var selectedCategory: String = "All"
    @State private var selectedExercise: Exercise?

    var categories: [String] {
        let allCategories = exercises.map { $0.category }
        return Array(Set(allCategories)).sorted()
    }

    private var categoryFilters: [String] {
        ["All"] + categories
    }

    private var completionIDs: Set<String> {
        Set(completions.map(\.exerciseID))
    }

    private var recentCompletionIDs: [String] {
        var uniqueIDs: [String] = []
        for completion in completions {
            if uniqueIDs.contains(completion.exerciseID) { continue }
            uniqueIDs.append(completion.exerciseID)
            if uniqueIDs.count == 3 { break }
        }
        return uniqueIDs
    }

    private var upNextExercises: [Exercise] {
        let incomplete = exercises.filter { !completionIDs.contains($0.id) }
        return Array(incomplete.prefix(3))
    }

    private var recentlyCompletedExercises: [Exercise] {
        recentCompletionIDs.compactMap { id in
            exercises.first(where: { $0.id == id })
        }
    }

    private var filteredExercises: [Exercise] {
        if selectedCategory == "All" { return exercises }
        return exercises.filter { $0.category == selectedCategory }
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.secondaryBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TopHeadlineView(
                        title: "Exercises",
                        subtitle: "Tap once to start any practice"
                    )

                    quickToolsSection

                    if exercises.isEmpty {
                        Text("No exercises available.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                    } else {
                        if !upNextExercises.isEmpty {
                            sectionTitle("Up Next")
                            VStack(spacing: 10) {
                                ForEach(upNextExercises) { exercise in
                                    exerciseCard(exercise, showCategory: true, isComplete: false)
                                }
                            }
                        }

                        if !recentlyCompletedExercises.isEmpty {
                            sectionTitle("Recently Completed")
                            VStack(spacing: 10) {
                                ForEach(recentlyCompletedExercises) { exercise in
                                    exerciseCard(exercise, showCategory: true, isComplete: true)
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categoryFilters, id: \.self) { category in
                                    categoryChip(category)
                                }
                            }
                            .padding(.vertical, 2)
                        }

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
                                                isComplete: completionIDs.contains(exercise.id)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 8)
                }
                .responsiveMaxWidth()
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
        }
#if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .onAppear {
            exercises = ExerciseLibrary.shared.exercises
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
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
            sectionTitle("Quick Tools & Mindset")

            VStack(spacing: 8) {
                NavigationLink(destination: AffirmationPlayerView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryColor)
                        
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
                            .foregroundStyle(Theme.primaryColor)
                        
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

                quickToolButton(title: "Breathing Reset (1 min)", durationSeconds: 60)
                quickToolButton(title: "Breathing Reset (2 min)", durationSeconds: 120)
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
    }

    private func quickToolButton(title: String, durationSeconds: Int) -> some View {
        Button {
            BreathingPresenter.shared.present(durationSeconds: durationSeconds, autoStart: true)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wind")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryColor)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Theme.toggleBackgroundColor(for: .light))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func categoryChip(_ category: String) -> some View {
        Button {
            selectedCategory = category
            HapticManager.shared.lightImpact()
        } label: {
                Text(category)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(selectedCategory == category ? Theme.backgroundColor : Theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedCategory == category ? Theme.primaryColor : Theme.tertiaryBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
            .accessibilityLabel("\(category) category filter")
    }

    private func exerciseCard(_ exercise: Exercise, showCategory: Bool, isComplete: Bool) -> some View {
        Button {
            selectedExercise = exercise
            HapticManager.shared.selection()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .multilineTextAlignment(.leading)

                        if showCategory {
                            Text(exercise.category)
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
                        .foregroundStyle(Theme.primaryColor)
                }
                .foregroundStyle(Theme.secondaryText)
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.title). \(exercise.description). \(exercise.steps.count) steps, \(exercise.duration) minutes.")
        .accessibilityHint("Tap to start exercise")
    }
}
