import OSLog
import SwiftData
import SwiftUI

struct CourseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var course: Course

    let libraryItems: [LibraryItem]

    @State private var currentIndex: Int

    private var orderedItems: [LibraryItem] {
        course.orderedItems(from: libraryItems)
    }

    private var currentItem: LibraryItem? {
        guard orderedItems.indices.contains(currentIndex) else { return orderedItems.first }
        return orderedItems[currentIndex]
    }

    private var progress: Double {
        guard !orderedItems.isEmpty else { return 0 }
        return Double(course.completedItemIDs.count) / Double(orderedItems.count)
    }

    init(course: Course, libraryItems: [LibraryItem]) {
        self.course = course
        self.libraryItems = libraryItems
        self._currentIndex = State(initialValue: course.progressIndex(in: libraryItems))
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppScreenHeadline(title: course.title)

                    progressHeader

                    if let currentItem {
                        currentItemCard(currentItem)
                    }

                    sequenceList
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
            currentIndex = course.progressIndex(in: libraryItems)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(course.isCompleted ? "Course completed" : "\(course.completedItemIDs.count) of \(orderedItems.count) completed")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(course.isCompleted ? Theme.successGreen : Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }

            ProgressView(value: progress)
                .tint(course.isCompleted ? Theme.successGreen : themeManager.selectedColor)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func currentItemCard(_ item: LibraryItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Step")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.type.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 42, height: 42)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(item.type.rawValue) / \(item.duration)m")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            NavigationLink(destination: LibraryItemDestinationView(item: item)) {
                HStack {
                    Image(systemName: "arrow.up.right.circle.fill")
                    Text("Open Step")
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(themeManager.selectedColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if !course.completedItemIDs.contains(item.id) {
                Button {
                    complete(item)
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Mark Complete")
                    }
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(themeManager.selectedColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var sequenceList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Path")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.6)

            ForEach(Array(orderedItems.enumerated()), id: \.element.id) { index, item in
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

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.type.rawValue)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()

                        if course.completedItemIDs.contains(item.id) {
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

    private func complete(_ item: LibraryItem) {
        course.markCompleted(itemID: item.id)

        if let nextIndex = orderedItems.firstIndex(where: { !course.completedItemIDs.contains($0.id) }) {
            currentIndex = nextIndex
        }

        do {
            try modelContext.save()
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Library").error("Failed to save course progress: \(error.localizedDescription, privacy: .private)")
        }
    }
}
