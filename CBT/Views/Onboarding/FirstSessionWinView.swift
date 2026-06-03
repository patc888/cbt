import SwiftData
import SwiftUI

struct FirstSessionWinView: View {
    private enum Step {
        case welcome
        case action
        case success
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @AppStorage(DailyPlanPersonalizationKeys.goals) private var savedGoals = ""
    @AppStorage(DailyPlanPersonalizationKeys.interests) private var savedInterests = ""

    let onFinish: () -> Void

    @State private var step: Step = .welcome
    @State private var selectedWin: FirstSessionWinKind = .moodCheckIn
    @State private var moodScore = 6
    @State private var planTitle = ""
    @State private var wantsReminder = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var selectedGoals: [DailyPlanGoal] {
        decodeSavedIDs(savedGoals).compactMap(DailyPlanGoal.init(rawValue:))
    }

    private var selectedInterests: [DailyPlanInterest] {
        decodeSavedIDs(savedInterests).compactMap(DailyPlanInterest.init(rawValue:))
    }

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    switch step {
                    case .welcome:
                        welcomeContent
                    case .action:
                        actionContent
                    case .success:
                        successContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 28)
                .responsiveMaxWidth()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: step == .success ? "checkmark.seal.fill" : "sparkle.magnifyingglass")
                .font(.system(size: 42, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 88, height: 88)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(headerTitle)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(headerMessage)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var headerTitle: String {
        switch step {
        case .welcome:
            return String(localized: "Start with one small win")
        case .action:
            return actionTitle
        case .success:
            return String(localized: "That counted")
        }
    }

    private var headerMessage: String {
        switch step {
        case .welcome:
            return String(localized: "Before Home opens, choose one quick action. It will be saved to your Daily Plan so you can see today already has a helpful step in it.")
        case .action:
            return actionMessage
        case .success:
            return successMessage
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 16) {
            preferenceSummary
            quickWinChoices

            Button {
                HapticManager.shared.selection()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    step = .action
                }
            } label: {
                Label("Continue", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(DSPrimaryButtonStyle())
        }
    }

    private var preferenceSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Daily Plan is tuned for", systemImage: "slider.horizontal.3")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            if selectedGoals.isEmpty && selectedInterests.isEmpty {
                Text("You can personalize more later. For now, CBT will keep today simple and practical.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(selectedGoals.map(\.title) + selectedInterests.map(\.title), id: \.self) { title in
                        Text(title)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(themeManager.selectedColor.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var quickWinChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a quick win")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            ForEach([FirstSessionWinKind.moodCheckIn, .breathing, .todaysPlan]) { kind in
                Button {
                    HapticManager.shared.selection()
                    selectedWin = kind
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedWin == kind ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedWin == kind ? themeManager.selectedColor : Theme.tertiaryText)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(choiceTitle(for: kind))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                            Text(choiceSubtitle(for: kind))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        selectedWin == kind ? themeManager.selectedColor.opacity(0.1) : DSTheme.cardBackground,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selectedWin == kind ? themeManager.selectedColor.opacity(0.28) : Theme.tertiaryText.opacity(0.14), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedWin == kind ? .isSelected : [])
            }
        }
    }

    private var actionContent: some View {
        VStack(spacing: 16) {
            actionCard

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                completeSelectedWin()
            } label: {
                Label(isSaving ? "Saving" : "Save Progress", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(isSaving)

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    step = .welcome
                }
            } label: {
                Text("Choose a Different Win")
            }
            .buttonStyle(DSSecondaryButtonStyle(size: .medium))
        }
    }

    @ViewBuilder
    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(actionTitle, systemImage: actionIcon)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            switch selectedWin {
            case .moodCheckIn:
                VStack(alignment: .leading, spacing: 10) {
                    Text("How is your mood right now?")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Slider(value: moodBinding, in: 1...10, step: 1)
                    Text("\(moodScore)/10")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(themeManager.selectedColor)
                }
            case .breathing:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Take a slow breath in, let it out, and give yourself one quiet minute. Tap save when you are ready to count it.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: 1)
                        .tint(themeManager.selectedColor)
                    Text("60-second breathing reset")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }
            case .todaysPlan:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Name one small thing that would make today a little easier.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    TextField("One small step for today", text: $planTitle, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...3)
                }
            case .existingActivity:
                EmptyView()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Saved to Daily Plan", systemImage: "checkmark.seal.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Text("When you enter Home, today will already show this win as complete.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Toggle(isOn: $wantsReminder) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Offer a reminder tomorrow")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("A gentle check-in prompt, only if notifications are allowed.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .toggleStyle(.switch)
            .padding(16)
            .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                enterHome()
            } label: {
                Label("Enter Home", systemImage: "house.fill")
            }
            .buttonStyle(DSPrimaryButtonStyle())
        }
    }

    private var actionTitle: String {
        choiceTitle(for: selectedWin)
    }

    private var actionMessage: String {
        switch selectedWin {
        case .moodCheckIn:
            return String(localized: "A quick check-in gives today a starting point.")
        case .breathing:
            return String(localized: "A short reset can be enough to mark a real pause.")
        case .todaysPlan:
            return String(localized: "A small plan gives the day one clear next step.")
        case .existingActivity:
            return ""
        }
    }

    private var actionIcon: String {
        switch selectedWin {
        case .moodCheckIn:
            return "face.smiling"
        case .breathing:
            return "wind"
        case .todaysPlan:
            return "calendar.badge.clock"
        case .existingActivity:
            return "checkmark.seal.fill"
        }
    }

    private var successMessage: String {
        selectedWin.homeTitle + String(localized: ". One useful action is already part of today.")
    }

    private var moodBinding: Binding<Double> {
        Binding(
            get: { Double(moodScore) },
            set: { moodScore = Int($0.rounded()) }
        )
    }

    private func choiceTitle(for kind: FirstSessionWinKind) -> String {
        switch kind {
        case .moodCheckIn:
            return String(localized: "Check in with mood")
        case .breathing:
            return String(localized: "Complete 60-second breathing")
        case .todaysPlan:
            return String(localized: "Create today's plan")
        case .existingActivity:
            return String(localized: "Use existing progress")
        }
    }

    private func choiceSubtitle(for kind: FirstSessionWinKind) -> String {
        switch kind {
        case .moodCheckIn:
            return String(localized: "Save one simple mood rating.")
        case .breathing:
            return String(localized: "Count a short calming reset.")
        case .todaysPlan:
            return String(localized: "Set one small step for today.")
        case .existingActivity:
            return ""
        }
    }

    private func completeSelectedWin() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        do {
            try FirstSessionWinService.complete(
                kind: selectedWin,
                modelContext: modelContext,
                moodScore: moodScore,
                planTitle: planTitle
            )
            HapticManager.shared.success()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                step = .success
            }
        } catch {
            errorMessage = String(localized: "Progress could not be saved. Please try again.")
        }

        isSaving = false
    }

    private func enterHome() {
        FirstSessionWinService.setTomorrowReminderOptIn(wantsReminder)
        if wantsReminder {
            Task {
                await FirstSessionWinService.scheduleTomorrowReminderIfPossible()
            }
        }
        onFinish()
    }

    private func decodeSavedIDs(_ rawValue: String) -> [String] {
        rawValue
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > width {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
