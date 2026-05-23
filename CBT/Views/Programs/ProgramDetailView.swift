import SwiftUI
import SwiftData
import Combine

struct ProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query private var progresses: [ProgramProgress]
    
    let program: CBTProgram
    
    // Timer to automatically refresh the remaining time until unlock every minute
    @State private var timeRefreshTrigger = false
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    init(program: CBTProgram) {
        self.program = program
        let id = program.id
        self._progresses = Query(filter: #Predicate<ProgramProgress> { $0.programID == id && !$0.isDeleted })
    }
    
    var currentProgress: ProgramProgress? {
        progresses.first
    }
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Premium Top Headline Bar
                TopHeadlineView(
                    title: program.title,
                    leading: {
                        Button {
                            HapticManager.shared.lightImpact()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(themeManager.selectedColor)
                                .frame(width: 32, height: 32)
                                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header description & overall completion status card
                        headerStatusCard
                        
                        // Days list
                        ForEach(program.days, id: \.dayNumber) { day in
                            dayRowView(for: day)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(refreshTimer) { _ in
            // Trigger UI update to refresh countdown remaining time
            timeRefreshTrigger.toggle()
        }
    }
    
    // MARK: - Subviews
    
    private var headerStatusCard: some View {
        let completed = currentProgress?.completedDays ?? 0
        let total = program.days.count
        let progressPercent = Double(completed) / Double(total)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 48, height: 48)
                    .background(themeManager.selectedColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Personal Growth Course")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .textCase(.uppercase)
                        .tracking(1.0)
                    
                    Text("\(completed) of \(total) Days Completed")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                }
            }
            
            Text("Pace yourself through daily bite-sized psychoeducation modules. Each step contains science-backed methods designed to rewire avoidance patterns and build long-term cognitive agility.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            ProgressView(value: progressPercent)
                .tint(themeManager.selectedColor)
                .background(themeManager.trackBackgroundColor(for: colorScheme))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .clipShape(Capsule())
                .padding(.top, 4)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
    
    private func dayRowView(for day: CBTProgramDay) -> some View {
        let completedDays = currentProgress?.completedDays ?? 0
        let isCompleted = completedDays >= day.dayNumber
        let locked = isDayLocked(dayNumber: day.dayNumber, progress: currentProgress)
        
        return VStack(alignment: .leading, spacing: 14) {
            // Card Title Row
            HStack(alignment: .center) {
                Text("DAY \(day.dayNumber)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(locked ? Theme.secondaryText : themeManager.selectedColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(locked ? Theme.tertiaryBackground : themeManager.selectedColor.opacity(0.12))
                    .clipShape(Capsule())
                
                Text(day.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(locked ? Theme.secondaryText : Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.successGreen)
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.secondaryText)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(themeManager.selectedColor)
                }
            }
            
            if !locked {
                // Reading Block
                Text(day.readingBlock)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actionable Tip Surface
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeManager.selectedColor)
                        
                        Text("ACTIONABLE PRACTICE")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .tracking(0.5)
                    }
                    
                    Text(day.actionableTip)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(themeManager.selectedColor.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(0.18), lineWidth: 1)
                )
                
                // Complete Button
                if !isCompleted {
                    Button {
                        HapticManager.shared.success()
                        completeDay(day.dayNumber)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Mark Day \(day.dayNumber) Completed")
                        }
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(themeManager.selectedColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: themeManager.selectedColor.opacity(0.3), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                    .premiumPressEffect()
                    .padding(.top, 6)
                }
            } else {
                // Locked State message
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.secondaryText)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(getLockReasonHeader(dayNumber: day.dayNumber, completedDays: completedDays))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        
                        Text(getLockReasonSubheader(dayNumber: day.dayNumber, completedDays: completedDays))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .opacity(locked ? 0.65 : 1.0)
    }
    
    // MARK: - Logic Helpers
    
    func isDayLocked(dayNumber: Int, progress: ProgramProgress?) -> Bool {
        let completedDays = progress?.completedDays ?? 0
        if dayNumber <= completedDays {
            return false // Already completed
        }
        if dayNumber > completedDays + 1 {
            return true // Future days locked
        }
        
        // For the next sequential day
        guard let lastCompletedAt = progress?.lastCompletedAt else {
            return false // First day is unlocked
        }
        
        let timeSinceLastCompletion = Date().timeIntervalSince(lastCompletedAt)
        return timeSinceLastCompletion < 24 * 60 * 60
    }
    
    private func getLockReasonHeader(dayNumber: Int, completedDays: Int) -> String {
        if dayNumber > completedDays + 1 {
            return "Sequence Locked"
        }
        return "24-Hour Time Gate"
    }
    
    private func getLockReasonSubheader(dayNumber: Int, completedDays: Int) -> String {
        // Suppress compile warning by referencing timeRefreshTrigger
        _ = timeRefreshTrigger
        
        if dayNumber > completedDays + 1 {
            return "Complete previous days before unlocking Day \(dayNumber)."
        }
        
        guard let lastCompletedAt = currentProgress?.lastCompletedAt else {
            return "Complete the previous day first."
        }
        
        let unlockDate = lastCompletedAt.addingTimeInterval(24 * 60 * 60)
        let now = Date()
        guard unlockDate > now else {
            return "Ready to begin!"
        }
        
        let diff = Calendar.current.dateComponents([.hour, .minute], from: now, to: unlockDate)
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0
        
        if hours > 0 {
            return "Next day unlocks in \(hours)h \(minutes)m."
        } else if minutes > 0 {
            return "Next day unlocks in \(minutes)m."
        } else {
            return "Next day unlocks in less than a minute."
        }
    }
    
    private func completeDay(_ dayNumber: Int) {
        if let progress = currentProgress {
            progress.completedDays = dayNumber
            progress.lastCompletedAt = Date()
        } else {
            let newProgress = ProgramProgress(
                programID: program.id,
                completedDays: dayNumber,
                lastCompletedAt: Date()
            )
            modelContext.insert(newProgress)
        }
        try? modelContext.save()
    }
}
