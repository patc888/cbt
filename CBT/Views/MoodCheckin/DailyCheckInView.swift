import SwiftUI
import SwiftData
import OSLog

struct DailyCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var existingEntry: MoodEntry?
    @State private var moodRating = 6.0
    @State private var anxietyStressRating = 4.0
    @State private var energyRating = 5.0
    @State private var sleepQuality = 3
    @State private var primaryTrigger = DailyCheckInTrigger.none
    @State private var note = ""
    @State private var helpedToday = ""
    @State private var didSave = false
    @State private var errorMessage: String?
    @State private var showingReset = false

    private var isEditing: Bool {
        existingEntry != nil
    }

    private var saveTitle: String {
        isEditing ? String(localized: "Update Check-In") : String(localized: "Save Check-In")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if didSave {
                            successCard
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else if existingEntry == nil {
                            emptyStateCard
                        } else {
                            editingStateCard
                        }

                        ratingsCard
                        detailsCard
                        saveButton
                        notReadyActions
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                    .responsiveMaxWidth()
                }
            }
            .navigationTitle(isEditing ? String(localized: "Update Check-In") : String(localized: "Daily Check-In"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSave ? String(localized: "Close") : String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            loadToday()
        }
        .sheet(isPresented: $showingReset) {
            NavigationStack {
                BreathingResetView(
                    durationSeconds: 60,
                    pattern: .box,
                    autoStart: true,
                    showsDismissControl: true,
                    showControls: true,
                    hideBackground: false,
                    onComplete: nil,
                    onDismiss: { showingReset = false }
                )
            }
            .dsSheetPresentation()
        }
        #if targetEnvironment(macCatalyst)
        .frame(minWidth: 560, idealWidth: 600, minHeight: 640, idealHeight: 700)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "A quick read on today"), systemImage: "sun.min.fill")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: "Use your first answer. This is meant to take about a minute."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyStateCard: some View {
        DailyCheckInStatusCard(
            systemImage: "sparkles",
            title: String(localized: "No check-in yet today"),
            message: String(localized: "A few simple ratings are enough to start noticing patterns."),
            tint: themeManager.selectedColor
        )
    }

    private var editingStateCard: some View {
        DailyCheckInStatusCard(
            systemImage: "checkmark.circle.fill",
            title: String(localized: "Today's check-in is saved"),
            message: String(localized: "You can update it here without creating another entry."),
            tint: Theme.successGreen
        )
    }

    private var successCard: some View {
        DailyCheckInStatusCard(
            systemImage: "checkmark.seal.fill",
            title: String(localized: "Saved for today"),
            message: String(localized: "Nice and simple. Your Daily Plan will count this as complete."),
            tint: Theme.successGreen
        )
        .accessibilityAddTraits(.isStaticText)
    }

    private var ratingsCard: some View {
        DailyCheckInCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "Right now"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                DailyCheckInRatingRow(
                    title: String(localized: "Mood"),
                    lowLabel: String(localized: "Low"),
                    highLabel: String(localized: "Bright"),
                    value: $moodRating,
                    tint: themeManager.selectedColor
                )

                DailyCheckInRatingRow(
                    title: String(localized: "Anxiety / Stress"),
                    lowLabel: String(localized: "Easy"),
                    highLabel: String(localized: "High"),
                    value: $anxietyStressRating,
                    tint: Color.orange
                )

                DailyCheckInRatingRow(
                    title: String(localized: "Energy"),
                    lowLabel: String(localized: "Low"),
                    highLabel: String(localized: "Full"),
                    value: $energyRating,
                    tint: Color.teal
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Sleep Quality"))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Picker(String(localized: "Sleep Quality"), selection: $sleepQuality) {
                        ForEach(DailyCheckInSleepQuality.allCases) { quality in
                            Text(quality.title).tag(quality.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(String(localized: "Sleep quality"))
                    .accessibilityValue(DailyCheckInSleepQuality(rawValue: sleepQuality)?.title ?? "")
                }
            }
        }
    }

    private var detailsCard: some View {
        DailyCheckInCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "A little context"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Primary Trigger"))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Picker(String(localized: "Primary Trigger"), selection: $primaryTrigger) {
                        ForEach(DailyCheckInTrigger.allCases) { trigger in
                            Label(trigger.title, systemImage: trigger.systemImage).tag(trigger)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DSTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(String(localized: "Primary trigger"))
                    .accessibilityValue(primaryTrigger.title)
                }

                DailyCheckInTextField(
                    title: String(localized: "Optional Note"),
                    placeholder: String(localized: "Anything worth remembering?"),
                    text: $note
                )

                DailyCheckInTextField(
                    title: String(localized: "What Helped Today?"),
                    placeholder: String(localized: "A walk, music, talking it out..."),
                    text: $helpedToday
                )

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(DSTheme.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(String(localized: "Save error"))
                        .accessibilityValue(errorMessage)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label(saveTitle, systemImage: isEditing ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
        }
        .buttonStyle(DSPrimaryButtonStyle())
        .accessibilityLabel(saveTitle)
        .accessibilityHint(String(localized: "Saves today's daily check-in."))
    }

    private var notReadyActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                notReadyButtons
            }

            VStack(spacing: 10) {
                notReadyButtons
            }
        }
    }

    @ViewBuilder
    private var notReadyButtons: some View {
        Button {
            saveMoodOnly()
        } label: {
            Label(String(localized: "Just save the mood"), systemImage: "heart.circle")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))

        Button {
            showingReset = true
        } label: {
            Label(String(localized: "Do a 60-second reset instead"), systemImage: "wind")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))

        Button {
            dismiss()
        } label: {
            Label(String(localized: "Come back later"), systemImage: "clock")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))
    }

    private func loadToday() {
        guard existingEntry == nil else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()

        do {
            var descriptor = FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> {
                    $0.isDeleted == false &&
                    $0.createdAt >= start &&
                    $0.createdAt < end
                },
                sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            if let entry = try modelContext.fetch(descriptor).first {
                existingEntry = entry
                moodRating = Double(entry.moodScore)
                anxietyStressRating = Double(entry.anxietyStressScore ?? entry.intensity ?? 4)
                energyRating = Double(entry.energyScore ?? 5)
                sleepQuality = entry.sleepQualityScore ?? 3
                primaryTrigger = DailyCheckInTrigger(entry.triggers.first)
                note = entry.notes ?? ""
                helpedToday = entry.helpedToday ?? ""
            }
        } catch {
            errorMessage = String(localized: "Could not load today's check-in.")
            AppLogger.make(category: "Data").error("Failed to load daily check-in: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHelped = helpedToday.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let mood = Int(moodRating.rounded())
        let stress = Int(anxietyStressRating.rounded())
        let energy = Int(energyRating.rounded())
        let triggers = primaryTrigger == .none ? [] : [primaryTrigger.rawValue]

        do {
            let entry = existingEntry ?? MoodEntry(createdAt: now, moodScore: mood)
            entry.moodScore = MoodEntry.clampMoodScore(mood)
            entry.intensity = stress
            entry.anxietyStressScore = stress
            entry.energyScore = energy
            entry.sleepQualityScore = sleepQuality
            entry.triggers = triggers
            entry.notes = trimmedNote.isEmpty ? nil : trimmedNote
            entry.helpedToday = trimmedHelped.isEmpty ? nil : trimmedHelped

            if existingEntry == nil {
                modelContext.insert(entry)
                existingEntry = entry
            }

            try upsertMoodCheckIn(createdAt: entry.createdAt, moodScore: mood, notes: entry.notes)
            try modelContext.save()
            AchievementService.shared.evaluateAchievements(in: modelContext)
            PersonalizedReminderService.shared.recordMoodCheckInResponse(at: now)
            ReviewManager.shared.logSignificantAction()

            HapticManager.shared.success()
            errorMessage = nil
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                didSave = true
            }
        } catch {
            errorMessage = String(localized: "Could not save. Please try again.")
            AppLogger.make(category: "Data").error("Failed to save daily check-in: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func saveMoodOnly() {
        let now = Date()
        let mood = Int(moodRating.rounded())

        do {
            let entry = existingEntry ?? MoodEntry(createdAt: now, moodScore: mood)
            entry.moodScore = MoodEntry.clampMoodScore(mood)
            entry.intensity = nil
            entry.anxietyStressScore = nil
            entry.energyScore = nil
            entry.sleepQualityScore = nil
            entry.triggers = []
            entry.notes = nil
            entry.helpedToday = nil

            if existingEntry == nil {
                modelContext.insert(entry)
                existingEntry = entry
            }

            try upsertMoodCheckIn(createdAt: entry.createdAt, moodScore: mood, notes: nil)
            try modelContext.save()
            AchievementService.shared.evaluateAchievements(in: modelContext)
            PersonalizedReminderService.shared.recordMoodCheckInResponse(at: now)
            ReviewManager.shared.logSignificantAction()

            note = ""
            helpedToday = ""
            primaryTrigger = .none
            HapticManager.shared.success()
            errorMessage = nil
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                didSave = true
            }
        } catch {
            errorMessage = String(localized: "Could not save. Please try again.")
            AppLogger.make(category: "Data").error("Failed to save mood-only daily check-in: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func upsertMoodCheckIn(createdAt: Date, moodScore: Int, notes: String?) throws {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: createdAt)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? createdAt
        var descriptor = FetchDescriptor<MoodCheckIn>(
            predicate: #Predicate<MoodCheckIn> {
                $0.isDeleted == false &&
                $0.createdAt >= start &&
                $0.createdAt < end
            },
            sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let checkIn = try modelContext.fetch(descriptor).first {
            checkIn.moodScore = moodScore
            checkIn.notes = notes
        } else {
            modelContext.insert(MoodCheckIn(createdAt: createdAt, moodScore: moodScore, notes: notes))
        }
    }
}

private enum DailyCheckInSleepQuality: Int, CaseIterable, Identifiable {
    case poor = 1
    case light = 2
    case okay = 3
    case good = 4
    case great = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .poor: return String(localized: "Poor")
        case .light: return String(localized: "Light")
        case .okay: return String(localized: "Okay")
        case .good: return String(localized: "Good")
        case .great: return String(localized: "Great")
        }
    }
}

private enum DailyCheckInTrigger: String, CaseIterable, Identifiable {
    case none = "None"
    case work = "Work"
    case relationships = "Relationships"
    case health = "Health"
    case sleep = "Sleep"
    case money = "Money"
    case plans = "Plans"
    case uncertainty = "Uncertainty"

    var id: String { rawValue }

    init(_ value: String?) {
        self = Self.allCases.first { $0.rawValue == value } ?? .none
    }

    var title: String {
        switch self {
        case .none: return String(localized: "No clear trigger")
        case .work: return String(localized: "Work")
        case .relationships: return String(localized: "Relationships")
        case .health: return String(localized: "Health")
        case .sleep: return String(localized: "Sleep")
        case .money: return String(localized: "Money")
        case .plans: return String(localized: "Plans")
        case .uncertainty: return String(localized: "Uncertainty")
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "circle"
        case .work: return "briefcase"
        case .relationships: return "person.2"
        case .health: return "heart"
        case .sleep: return "moon"
        case .money: return "creditcard"
        case .plans: return "calendar"
        case .uncertainty: return "questionmark.circle"
        }
    }
}

private struct DailyCheckInCard<Content: View>: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(colorScheme == .dark ? 0.18 : 0.1), lineWidth: 1)
                }
        }
    }
}

private struct DailyCheckInStatusCard: View {
    let systemImage: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct DailyCheckInRatingRow: View {
    let title: String
    let lowLabel: String
    let highLabel: String
    @Binding var value: Double
    let tint: Color

    private var roundedValue: Int {
        Int(value.rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Spacer(minLength: 12)

                Text("\(roundedValue)/10")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            Slider(value: $value, in: 1...10, step: 1)
                .tint(tint)
                .accessibilityLabel(title)
                .accessibilityValue(String(localized: "\(roundedValue) out of 10"))

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.system(.caption2, design: .rounded).weight(.medium))
            .foregroundStyle(Theme.secondaryText)
        }
    }
}

private struct DailyCheckInTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(.body, design: .rounded))
                .padding(12)
                .background(DSTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(title)
        }
    }
}
