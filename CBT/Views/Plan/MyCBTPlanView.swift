import SwiftData
import SwiftUI

struct MyCBTPlanView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \AssessmentLog.date, order: .reverse) private var assessmentLogs: [AssessmentLog]
    @Query(sort: \ExerciseCompletion.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]
    @Query(sort: \FlexibleJournalEntry.date, order: .reverse) private var flexibleJournalEntries: [FlexibleJournalEntry]

    @AppStorage("myCBTPlan.focusArea") private var storedFocusArea = ""
    @AppStorage("myCBTPlan.reviewWeekID") private var reviewWeekID = ""

    private var focusArea: CBTPlanFocusArea {
        get {
            CBTPlanFocusArea(rawValue: storedFocusArea)
                ?? MyCBTPlanService.inferredFocusArea(from: assessmentLogs)
        }
        nonmutating set {
            storedFocusArea = newValue.rawValue
            reviewWeekID = ""
        }
    }

    private var currentWeekID: String {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return week.formatted(.iso8601.year().month().day())
    }

    private var snapshot: CBTPlanSnapshot {
        MyCBTPlanService.snapshot(
            focusArea: focusArea,
            assessmentLogs: assessmentLogs,
            exerciseCompletions: exerciseCompletions,
            flexibleJournalEntries: flexibleJournalEntries,
            reviewCompleted: reviewWeekID == currentWeekID
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppScreenHeadline(title: "My CBT Plan")

                        planHeader
                        focusPicker
                        arcSection
                    }
                    .dsContentLayout()
                    .padding(.bottom, 18)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(themeManager.selectedColor, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.focusArea.shortTitle)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(snapshot.weekStart.formatted(date: .abbreviated, time: .omitted)) - \(snapshot.weekEnd.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ProgressView(value: Double(snapshot.completedTargetCount), total: 3)
                .tint(themeManager.selectedColor)
                .accessibilityLabel("Weekly practice progress")

            Text("\(snapshot.completedTargetCount) of 3 weekly targets have activity recorded.")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var focusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus Area")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CBTPlanFocusArea.allCases) { area in
                        Button {
                            HapticManager.shared.selection()
                            focusArea = area
                        } label: {
                            Text(area.rawValue)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(focusArea == area ? .white : Theme.secondaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(focusArea == area ? themeManager.selectedColor : Theme.tertiaryBackground)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var arcSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Treatment Arc")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            CBTPlanArcCard(
                number: 1,
                title: "Baseline",
                detail: "\(snapshot.baselineTitle): \(snapshot.baselineDetail)",
                symbol: snapshot.hasBaseline ? "checkmark.seal.fill" : "waveform.path.ecg",
                isComplete: snapshot.hasBaseline,
                buttonTitle: snapshot.hasBaseline ? "Retake" : "Start",
                action: { open(.assessments) }
            )

            CBTPlanArcCard(
                number: 2,
                title: "Focus Area",
                detail: "This week is centered on \(focusArea.rawValue.lowercased()).",
                symbol: "scope",
                isComplete: true,
                buttonTitle: "Adjust",
                action: { }
            )

            CBTPlanArcCard(
                number: 3,
                title: "Weekly Skill",
                detail: focusArea.weeklySkill,
                symbol: "sparkle.magnifyingglass",
                isComplete: snapshot.weeklyExerciseCount > 0 || snapshot.weeklyJournalCount > 0,
                buttonTitle: "Practice",
                action: { open(.toolkit) }
            )

            practiceTargetsCard

            CBTPlanArcCard(
                number: 5,
                title: "Review",
                detail: snapshot.reviewCompleted ? "Weekly review marked complete." : "Look at what changed before choosing the next step.",
                symbol: snapshot.reviewCompleted ? "checkmark.circle.fill" : "chart.xyaxis.line",
                isComplete: snapshot.reviewCompleted,
                buttonTitle: snapshot.reviewCompleted ? "Insights" : "Complete",
                action: {
                    if snapshot.reviewCompleted {
                        open(.insights)
                    } else {
                        reviewWeekID = currentWeekID
                        HapticManager.shared.success()
                    }
                }
            )

            CBTPlanArcCard(
                number: 6,
                title: "Next Adjustment",
                detail: focusArea.adjustmentPrompt,
                symbol: "arrow.triangle.2.circlepath",
                isComplete: snapshot.reviewCompleted,
                buttonTitle: "Review Data",
                action: { open(.insights) }
            )
        }
    }

    private var practiceTargetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            CBTPlanArcHeader(number: 4, title: "Practice Targets", symbol: "target", isComplete: snapshot.completedTargetCount == 3)

            ForEach(Array(focusArea.practiceTargets.enumerated()), id: \.element.id) { index, target in
                Button {
                    open(target.destination)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: targetComplete(at: index) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(targetComplete(at: index) ? themeManager.selectedColor : Theme.tertiaryText)
                            .frame(width: 28)

                        Text(target.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func targetComplete(at index: Int) -> Bool {
        switch index {
        case 0:
            return snapshot.weeklyExerciseCount > 0 || snapshot.weeklyJournalCount > 0
        case 1:
            return snapshot.weeklyJournalCount > 0
        default:
            return snapshot.weeklyAssessmentCount > 0
        }
    }

    private func open(_ destination: CBTPlanDestination) {
        let tab: FloatingTab
        switch destination {
        case .assessments:
            tab = .assessments
        case .toolkit:
            tab = .toolkit
        case .journal:
            tab = .journal
        case .insights:
            tab = .insights
        }

        NotificationCenter.default.post(name: .appTabSelectionRequested, object: tab)
    }
}

private struct CBTPlanArcCard: View {
    let number: Int
    let title: String
    let detail: String
    let symbol: String
    let isComplete: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CBTPlanArcHeader(number: number, title: title, symbol: symbol, isComplete: isComplete)

            Text(detail)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct CBTPlanArcHeader: View {
    @Environment(ThemeManager.self) private var themeManager
    let number: Int
    let title: String
    let symbol: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(themeManager.selectedColor, in: Circle())

            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 28)

            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isComplete ? themeManager.selectedColor : Theme.tertiaryText)
        }
    }
}
