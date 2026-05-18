import SwiftUI
import SwiftData

struct ActivityPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Query(
        filter: #Predicate<PlannedActivity> { $0.isDeleted == false },
        sort: \PlannedActivity.scheduledDate,
        order: .reverse
    ) private var activities: [PlannedActivity]
    
    @State private var showingAddActivity = false
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TopHeadlineView(
                        title: "Activity Planner",
                        leading: { 
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                    )
                    
                    headerSection
                    
                    if activities.isEmpty {
                        emptyState
                    } else {
                        activitySections
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            addActivityButton
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingAddActivity) {
            AddActivityView()
        }
    }

    private var addActivityButton: some View {
        Button {
            HapticManager.shared.trigger(.medium)
            showingAddActivity = true
        } label: {
            Label("Schedule Activity", systemImage: "plus.circle.fill")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(themeManager.selectedColor)
                .clipShape(Capsule())
                .shadow(color: themeManager.selectedColor.opacity(0.3), radius: 10, y: 5)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Behavioral Activation")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(themeManager.selectedColor)
                .textCase(.uppercase)
            
            Text("Action precedes motivation. Schedule small tasks to prove your brain's predictions wrong.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.top, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Theme.secondaryText.opacity(0.5))
            
            Text("Your planner is empty")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            
            Text("Schedule a small 'nourishing' or 'mastery' task. Don't wait until you feel like it.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private var activitySections: some View {
        VStack(alignment: .leading, spacing: 24) {
            let pending = activities.filter { !$0.isCompleted }
            let completed = activities.filter { $0.isCompleted }
            
            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    
                    ForEach(pending) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
            
            if !completed.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Completed & Reflected")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    
                    ForEach(completed) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
        }
    }
}

struct ActivityRow: View {
    let activity: PlannedActivity
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingCompletion = false
    
    var body: some View {
        Button {
            if !activity.isCompleted {
                showingCompletion = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(activity.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    
                    Spacer(minLength: 8)
                    
                    CategoryBadge(category: activity.category)
                }
                
                if activity.isCompleted, let actual = activity.actualEnjoyment {
                    ComparisonView(predicted: activity.predictedEnjoyment, actual: actual)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Predicted Enjoyment:")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        
                        Text("\(activity.predictedEnjoyment)/10")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.selectedColor)
                        
                        Spacer(minLength: 8)
                        
                        Text("Tap to complete")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .padding(Theme.paddingMedium)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingCompletion) {
            ActivityCompletionView(activity: activity)
        }
    }
}

struct CategoryBadge: View {
    let category: String
    
    var body: some View {
        Text(category)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }
}

struct ComparisonView: View {
    let predicted: Int
    let actual: Int
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var horizontalLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Predicted")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
                Text("\(predicted)/10")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            
            Image(systemName: "arrow.right")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(Theme.secondaryText.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Actual")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(actual >= predicted ? Theme.successGreen : Theme.warningOrange)
                Text("\(actual)/10")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(actual >= predicted ? Theme.successGreen : Theme.warningOrange)
            }
            
            if actual > predicted {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("Better than expected!")
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.successGreen)
            }
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Predicted")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(predicted)/10")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }

                Image(systemName: "arrow.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(Theme.secondaryText.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Actual")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(actual >= predicted ? Theme.successGreen : Theme.warningOrange)
                    Text("\(actual)/10")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(actual >= predicted ? Theme.successGreen : Theme.warningOrange)
                }
            }

            if actual > predicted {
                Label("Better than expected!", systemImage: "sparkles")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.successGreen)
                    .lineLimit(2)
            }
        }
    }
}
