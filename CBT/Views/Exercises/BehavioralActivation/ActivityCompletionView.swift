import SwiftUI
import SwiftData

struct ActivityCompletionView: View {
    @Bindable var activity: PlannedActivity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var actualEnjoyment = 5.0
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var reminderPromptMoment: ReminderOptInMoment?
    @State private var isHandlingReminderPrompt = false
    @State private var helpfulnessResponse: HelpfulnessResponse?
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activity.title)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                            Text("Scheduled for \(activity.scheduledDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                            if let supportedValue = activity.supportedValue {
                                ValueBadge(value: supportedValue)
                            }
                        }
                        .padding(.top)
                        
                        Divider()
                        
                        sectionTitle("The Result")
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("How much did you ACTUALLY enjoy it?")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text("\(Int(actualEnjoyment))/10")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(themeManager.selectedColor)
                            }
                            
                            Slider(value: $actualEnjoyment, in: 0...10, step: 1)
                                .tint(themeManager.selectedColor)
                            
                            HStack {
                                Text("Not at all")
                                Spacer()
                                Text("Loved it")
                            }
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.secondaryText)
                        }
                        .padding()
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Predicted: \(activity.predictedEnjoyment)/10")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.secondaryText)
                            
                            if Int(actualEnjoyment) > activity.predictedEnjoyment {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Evidence: You enjoyed this \(Int(actualEnjoyment) - activity.predictedEnjoyment) points more than your brain predicted.")
                                        .font(.system(.callout, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Theme.successGreen)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .background(Theme.successGreen.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        
                        sectionTitle("What Helped?")
                        helpfulnessPicker

                        sectionTitle("Notes (Optional)")
                        TextField("Any reflections?", text: $notes, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .padding()
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Reflect on Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        completeActivity()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Could Not Save Reflection", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $reminderPromptMoment) { moment in
                ReminderOptInPromptView(
                    moment: moment,
                    isWorking: isHandlingReminderPrompt,
                    onAccept: {
                        handleReminderPromptAccepted(moment)
                    },
                    onDismiss: {
                        handleReminderPromptDismissed(moment)
                    }
                )
                .padding()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.secondaryText)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    private var helpfulnessPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Did this activity feel useful right now?")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 8) {
                ForEach(HelpfulnessResponse.allCases) { response in
                    Button {
                        helpfulnessResponse = response
                        HapticManager.shared.selection()
                    } label: {
                        Text(response.title)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(helpfulnessResponse == response ? themeManager.selectedColor : Theme.tertiaryBackground)
                    .foregroundStyle(helpfulnessResponse == response ? .white : Theme.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding()
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func completeActivity() {
        activity.actualEnjoyment = PlannedActivity.clampRating(Int(actualEnjoyment))
        activity.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        activity.isCompleted = true
        activity.completedAt = Date()
        activity.adaptiveMode = inferredCurrentMode().rawValue
        do {
            try modelContext.save()
            if let helpfulnessResponse {
                try? HelpfulnessFeedbackService.shared.record(
                    activityKind: .activityPlanning,
                    response: helpfulnessResponse,
                    itemID: activity.id.uuidString,
                    sourceScreen: "activity_completion",
                    in: modelContext
                )
            }
            AchievementService.shared.evaluateAchievements(in: modelContext)
            Task { @MainActor in
                await PersonalizedReminderService.shared.refreshEnabledReminders(modelContext: modelContext)
                let promptMoment = await ReminderOptInService.shared.promptIfEligible(
                    for: .firstPlannedActivityCompletion,
                    hasReachedMoment: completedActivityCount() == 1
                )
                if let promptMoment {
                    reminderPromptMoment = promptMoment
                } else {
                    dismiss()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func inferredCurrentMode() -> DailyPlanMode {
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
        )
        let latestMood = try? modelContext.fetch(descriptor).first
        return AdaptiveDifficultySelector.selectMode(
            latestMoodScore: latestMood?.moodScore,
            latestEnergyScore: latestMood?.energyScore,
            latestStressScore: latestMood?.anxietyStressScore ?? latestMood?.intensity,
            missedDays: nil,
            recentEngagementCount: 2
        )
    }

    private func completedActivityCount() -> Int {
        ((try? modelContext.fetch(FetchDescriptor<PlannedActivity>())) ?? [])
            .filter { !$0.isDeleted && $0.isCompleted }
            .count
    }

    private func handleReminderPromptAccepted(_ moment: ReminderOptInMoment) {
        guard !isHandlingReminderPrompt else { return }
        isHandlingReminderPrompt = true
        Task {
            _ = await ReminderOptInService.shared.accept(moment, modelContext: modelContext)
            await MainActor.run {
                reminderPromptMoment = nil
                isHandlingReminderPrompt = false
                dismiss()
            }
        }
    }

    private func handleReminderPromptDismissed(_ moment: ReminderOptInMoment) {
        ReminderOptInService.shared.dismiss(moment)
        reminderPromptMoment = nil
        dismiss()
    }
}
