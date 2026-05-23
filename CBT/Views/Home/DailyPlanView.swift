import SwiftUI
import SwiftData
import Observation

@Observable
final class DailyPlanViewModel {
    var isMoodComplete: Bool = false
    var isBreathingComplete: Bool = false
    var isLessonComplete: Bool = false
    
    var completedCount: Int {
        (isMoodComplete ? 1 : 0) + (isBreathingComplete ? 1 : 0) + (isLessonComplete ? 1 : 0)
    }
    
    var progressFraction: Double {
        Double(completedCount) / 3.0
    }
    
    @MainActor
    func refresh(context: ModelContext) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return }
        
        // 1. MoodCheckIn
        do {
            let moodFetch = FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> {
                    !$0.isDeleted && $0.createdAt >= todayStart && $0.createdAt < todayEnd
                }
            )
            let moodCount = try context.fetchCount(moodFetch)
            isMoodComplete = moodCount > 0
        } catch {
            isMoodComplete = false
        }
        
        // 2. BreathingSession
        do {
            let breathingFetch = FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> {
                    !$0.isDeleted && $0.createdAt >= todayStart && $0.createdAt < todayEnd
                }
            )
            let breathingCount = try context.fetchCount(breathingFetch)
            isBreathingComplete = breathingCount > 0
        } catch {
            isBreathingComplete = false
        }
        
        // 3. ProgramProgress
        do {
            let progressFetch = FetchDescriptor<ProgramProgress>(
                predicate: #Predicate<ProgramProgress> {
                    !$0.isDeleted
                }
            )
            let progressItems = try context.fetch(progressFetch)
            isLessonComplete = progressItems.contains { item in
                if let lastCompletedAt = item.lastCompletedAt {
                    return lastCompletedAt >= todayStart && lastCompletedAt < todayEnd
                }
                return false
            }
        } catch {
            isLessonComplete = false
        }
    }
}

struct DailyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var viewModel = DailyPlanViewModel()
    
    // Queries to trigger reactive updates in SwiftUI when database changes
    @Query private var moodCheckIns: [MoodCheckIn]
    @Query private var breathingSessions: [BreathingSession]
    @Query private var programProgresses: [ProgramProgress]
    
    let onLogMood: () -> Void
    let onDailyBreathing: () -> Void
    let onDailyLesson: () -> Void
    
    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Plan")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                        
                        Text(subtitleText)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Circular Progress Indicator
                    ZStack {
                        Circle()
                            .stroke(themeManager.trackBackgroundColor(for: colorScheme), lineWidth: 4)
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.progressFraction))
                            .stroke(
                                LinearGradient(
                                    colors: [themeManager.selectedColor, themeManager.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.progressFraction)
                        
                        Text("\(viewModel.completedCount)/3")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                    }
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(themeManager.trackBackgroundColor(for: colorScheme))
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.selectedColor, themeManager.secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(viewModel.progressFraction), height: 5)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.progressFraction)
                    }
                }
                .frame(height: 5)
                .padding(.vertical, 2)
                
                Divider()
                    .background(DSTheme.separator)
                
                // Checklist Items
                VStack(spacing: 12) {
                    DailyPlanRow(
                        title: "Log Your Mood",
                        subtitle: "Capture how you feel right now",
                        icon: "face.smiling",
                        isCompleted: viewModel.isMoodComplete,
                        action: onLogMood
                    )
                    
                    DailyPlanRow(
                        title: "Daily Breathing",
                        subtitle: "Calm your mind with a breathing reset",
                        icon: "wind",
                        isCompleted: viewModel.isBreathingComplete,
                        action: onDailyBreathing
                    )
                    
                    DailyPlanRow(
                        title: "Daily Lesson",
                        subtitle: "Learn a key CBT technique",
                        icon: "graduationcap",
                        isCompleted: viewModel.isLessonComplete,
                        action: onDailyLesson
                    )
                }
            }
        }
        .onAppear {
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: moodCheckIns) { _, _ in
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: breathingSessions) { _, _ in
            viewModel.refresh(context: modelContext)
        }
        .onChange(of: programProgresses) { _, _ in
            viewModel.refresh(context: modelContext)
        }
    }
    
    private var subtitleText: String {
        switch viewModel.completedCount {
        case 3:
            return "All tasks completed! Excellent work."
        case 2:
            return "Just one more to complete your plan!"
        case 1:
            return "Good start! Keep going."
        default:
            return "Complete today's 3 tasks for robust mental wellness."
        }
    }
}

struct DailyPlanRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let subtitle: String
    let icon: String
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isCompleted {
                HapticManager.shared.selection()
                action()
            }
        }) {
            HStack(spacing: 14) {
                // Checkbox / Completion Icon
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(Theme.successGreen.opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.successGreen)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .stroke(themeManager.selectedColor.opacity(0.3), lineWidth: 2)
                            .background(Circle().fill(themeManager.selectedColor.opacity(0.04)))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.selectedColor.opacity(0.8))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCompleted)
                
                // Text details
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(isCompleted ? Theme.secondaryText : Theme.primaryText)
                        .strikethrough(isCompleted, color: Theme.secondaryText.opacity(0.5))
                    
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }
                
                Spacer()
                
                // Action indicator
                if !isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.successGreen)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                    .fill(isCompleted ? Color.secondary.opacity(0.05) : Theme.toggleBackgroundColor(for: colorScheme))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }
}
