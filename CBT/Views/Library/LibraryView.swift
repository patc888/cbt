import OSLog
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: [SortDescriptor(\LibraryItem.category), SortDescriptor(\LibraryItem.title)])
    private var libraryItems: [LibraryItem]
    @Query(sort: \Course.title)
    private var courses: [Course]

    @State private var selectedCategory = "All"

    private var categories: [String] {
        ["All"] + LibraryService.shared.categories(for: libraryItems)
    }

    private var selectedItems: [LibraryItem] {
        guard selectedCategory != "All" else { return libraryItems }
        return libraryItems.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        AppScreenHeadline(title: "Library")

                        if !courses.isEmpty {
                            coursesSection
                        }

                        categoryTabs

                        libraryList(for: selectedCategory)
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
        .task {
            await seedLibrary()
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Courses")

            VStack(spacing: 10) {
                ForEach(courses) { course in
                    NavigationLink(destination: CourseDetailView(course: course, libraryItems: libraryItems)) {
                        courseRow(course)
                    }
                    .buttonStyle(.plain)
                }
            }
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

    private func libraryList(for category: String) -> some View {
        let items = category == "All" ? libraryItems : libraryItems.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Text("No library items available.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(Theme.paddingMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                ForEach(items) { item in
                    NavigationLink(destination: LibraryItemDestinationView(item: item)) {
                        libraryItemRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func courseRow(_ course: Course) -> some View {
        let total = course.orderedItems(from: libraryItems).count
        let completed = course.completedItemIDs.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: course.isCompleted ? "checkmark.seal.fill" : "graduationcap.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(course.isCompleted ? Theme.successGreen : themeManager.selectedColor)
                    .frame(width: 38, height: 38)
                    .background((course.isCompleted ? Theme.successGreen : themeManager.selectedColor).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("\(completed) of \(total) completed")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }

            ProgressView(value: progress)
                .tint(course.isCompleted ? Theme.successGreen : themeManager.selectedColor)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func libraryItemRow(_ item: LibraryItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.type.systemImage)
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
                        Text(item.type.rawValue)
                        Text(item.category)
                        Text("\(item.duration)m")
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.type.rawValue)
                        Text(item.category)
                        Text("\(item.duration)m")
                    }
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            }

            Spacer()
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(.title3))
                .foregroundStyle(themeManager.selectedColor)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryText)
            .tracking(0.6)
    }

    @MainActor
    private func seedLibrary() async {
        do {
            try LibraryService.shared.seedLibraryIfNeeded(in: modelContext)
        } catch {
            AppLogger.make(category: "Library").error("Failed to seed library: \(error.localizedDescription, privacy: .private)")
        }
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
        case .audio:
            LibraryAudioView(item: item)
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

private struct LibraryAudioView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @Environment(ThemeManager.self) private var themeManager

    let item: LibraryItem

    private var fileName: String {
        String(data: item.contentData, encoding: .utf8) ?? item.id
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppScreenHeadline(title: item.title)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(item.duration) minute audio")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)

                        Button {
                            if audioPlayer.isPlaying && audioPlayer.currentFileName == fileName.replacingOccurrences(of: ".mp3", with: "") {
                                audioPlayer.pause()
                            } else {
                                audioPlayer.playMP3(named: fileName)
                            }
                        } label: {
                            HStack {
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                Text(audioPlayer.isPlaying ? "Pause" : "Play")
                            }
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(themeManager.selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if let errorMessage = audioPlayer.errorMessage {
                            Text(errorMessage)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(Theme.paddingMedium)
                    .cardStyle()

                    Spacer(minLength: 0)
                }
                .responsiveMaxWidth()
                .padding(.horizontal)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 16)
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
}
