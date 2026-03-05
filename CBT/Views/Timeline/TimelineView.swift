import SwiftUI
import SwiftData

struct TimelineView: View {
    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var thoughtRecords: [ThoughtRecord]
    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]
    @Query(filter: #Predicate<JournalEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var journalEntries: [JournalEntry]

    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddMood = false
    @State private var showingAddThought = false

    private var groupedItems: [(key: Date, value: [TimelineItem])] {
        var items: [TimelineItem] = []

        for mood in moodEntries {
            items.append(TimelineItem(
                id: "mood-\(mood.id)",
                kind: .mood,
                date: mood.createdAt,
                title: "Mood Check-in",
                subtitle: mood.notes?.isEmpty == false ? mood.notes : "Score: \(mood.moodScore)/10",
                chips: mood.emotions,
                route: .mood(mood)
            ))
        }

        for thought in thoughtRecords {
            items.append(TimelineItem(
                id: "thought-\(thought.id)",
                kind: .thought,
                date: thought.createdAt,
                title: "Thought Record",
                subtitle: thought.situation.isEmpty ? "No situation recorded" : thought.situation,
                chips: thought.emotions + thought.distortions,
                route: .thought(thought)
            ))
        }

        for completion in exerciseCompletions {
            let exercise = ExerciseLibrary.shared.exercises.first(where: { $0.id == completion.exerciseID })
            let title = exercise?.title ?? "Exercise"
            let route: TimelineRoute = .exercise(exerciseID: completion.exerciseID)

            items.append(TimelineItem(
                id: "ex-\(completion.id)",
                kind: .exercise,
                date: completion.createdAt,
                title: title,
                subtitle: completion.notes?.isEmpty == false ? completion.notes : nil,
                chips: [],
                route: route
            ))
        }

        for journal in journalEntries {
            let durationLabel: String? = {
                guard let secs = journal.durationSeconds, secs > 0 else { return nil }
                if secs < 60 { return "\(secs)s" }
                let m = secs / 60
                let r = secs % 60
                return r > 0 ? "\(m)m \(r)s" : "\(m)m"
            }()
            
            let subtitle: String = {
                var parts: [String] = []
                if let kind = journal.sourceKind {
                    parts.append(SessionSourceKind(rawValue: kind)?.displayName ?? kind)
                }
                if let d = durationLabel {
                    parts.append(d)
                }
                return parts.isEmpty ? nil : parts.joined(separator: " • ")
            }() ?? ""

            items.append(TimelineItem(
                id: "journal-\(journal.id)",
                kind: .journal,
                date: journal.createdAt,
                title: journal.title,
                subtitle: subtitle.isEmpty ? nil : subtitle,
                chips: [],
                route: .journal(journal)
            ))
        }

        items.sort { $0.date > $1.date }

        let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.secondaryBackground.ignoresSafeArea()

            if groupedItems.isEmpty {
                VStack(spacing: 20) {
                    TopHeadlineView(title: "Timeline")
                        .padding(.horizontal)

                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.secondaryText)

                    Text("No Activity Yet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Your timeline will show your mood check-ins, thought records, and completed exercises.")
                        .font(.system(size: 14, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button {
                            HapticManager.shared.lightImpact()
                            showingAddMood = true
                        } label: {
                            Label("Log Mood", systemImage: "face.smiling")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(maxWidth: 220)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(Theme.primaryColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.shared.lightImpact()
                            showingAddThought = true
                        } label: {
                            Label("New Thought Record", systemImage: "brain")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(maxWidth: 220)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(Theme.secondaryColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)

                    Spacer()
                }
                .responsiveMaxWidth()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        TopHeadlineView(title: "Timeline")

                        ForEach(groupedItems, id: \.key) { date, items in
                            Section {
                                ForEach(items) { item in
                                    if let route = item.route {
                                        NavigationLink(value: route) {
                                            TimelineRow(item: item)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        TimelineRow(item: item)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(formatHeaderDate(date))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.secondaryText)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(Theme.secondaryBackground)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .responsiveMaxWidth()
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                quickActionButton(title: "+ Mood", color: Theme.primaryColor) {
                    showingAddMood = true
                }
                quickActionButton(title: "+ Thought", color: Theme.secondaryColor) {
                    showingAddThought = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingAddMood) {
            MoodCheckinView()
        }
        .sheet(isPresented: $showingAddThought) {
            NewThoughtRecordFlowView()
        }
        .navigationDestination(for: TimelineRoute.self) { route in
            switch route {
            case .mood(let entry):
                MoodDetailView(entry: entry)
            case .thought(let record):
                ThoughtRecordDetailView(record: record)
            case .exercise(let exerciseID):
                if let exercise = ExerciseLibrary.shared.exercises.first(where: { $0.id == exerciseID }) {
                    ExerciseDetailView(exercise: exercise)
                } else {
                    ContentUnavailableView(
                        "Exercise Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This exercise is no longer available.")
                    )
                }
            case .journal(let entry):
                JournalEntryDetailView(entry: entry)
            }
        }
    }

    private func quickActionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.lightImpact()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.cardBackground)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.05 : 0), radius: colorScheme == .dark ? 2 : 0)
        }
        .buttonStyle(.plain)
    }

    private func formatHeaderDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}
