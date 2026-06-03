import SwiftData
import SwiftUI

struct CopingToolkitView: View {
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \SafetyPlan.updatedAt, order: .reverse) private var safetyPlans: [SafetyPlan]
    @State private var selectedFilter: CopingToolkitFilter?
    @State private var selectedExercise: Exercise?
    @State private var showingCopingPlan = false
    @State private var showingEmergencyKitLimit = false
    @State private var refreshToken = 0

    private let service = CopingToolkitService.shared
    private let store = CopingToolkitStore()

    private var visibleTools: [CopingToolkitTool] {
        service.filteredTools(for: selectedFilter)
    }

    private var favorites: [CopingToolkitTool] {
        service.favorites(using: store, limit: 4)
    }

    private var savedPlanTools: [CopingToolkitTool] {
        service.copingPlanTools(using: store, limit: store.maximumCopingPlanTools)
    }

    private var recentlyUsed: [CopingToolkitTool] {
        service.recentlyUsed(using: store, limit: 4)
    }

    private var trustedPhoneContact: EmergencyContact? {
        safetyPlans.first?.emergencyContacts.first {
            !$0.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        AppScreenHeadline(title: "Coping Toolkit")

                        CrisisSupportNoticeView(
                            style: .full,
                            planActionTitle: String(localized: "Open Coping Plan"),
                            onOpenPlan: {
                                store.recordUsage("toolkit_need_help")
                                showingCopingPlan = true
                                refreshToken &+= 1
                            }
                        )

                        filterChips

                        if !favorites.isEmpty {
                            toolSection(title: "Favorites", tools: favorites)
                        }

                        if savedPlanTools.isEmpty {
                            emergencyKitEmptyCard
                        } else {
                            emergencyKitSection(tools: savedPlanTools)
                        }

                        if !recentlyUsed.isEmpty {
                            toolSection(title: "Recently used", tools: recentlyUsed)
                        }

                        toolSection(
                            title: selectedFilter?.title ?? "All quick tools",
                            tools: visibleTools
                        )

                        disclaimer
                    }
                    .id(refreshToken)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset)
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .sheet(item: $selectedExercise) { exercise in
            NavigationStack {
                ExerciseDetailView(exercise: exercise)
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingCopingPlan) {
            NavigationStack {
                SafetyPlanView()
            }
            .dsSheetPresentation()
        }
        .alert("Emergency Kit is full", isPresented: $showingEmergencyKitLimit) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Keep this kit to 3-5 tools so it stays quick to use. Remove one before pinning another.")
        }
    }

    private var needHelpCard: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Need help now?")
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(DSTheme.primaryText)
                        Text("Use immediate support actions, then open your rough patch plan for the steps you prepared.")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let trustedPhoneContact {
                        Text("Reach a trusted person")
                            .font(DSTypography.caption.weight(.bold))
                            .foregroundStyle(DSTheme.secondaryText)

                        HStack(spacing: 8) {
                            crisisActionButton(
                                title: "Call \(contactName(trustedPhoneContact))",
                                systemImage: "phone.fill",
                                url: phoneURL(scheme: "tel", number: trustedPhoneContact.phoneNumber)
                            )

                            crisisActionButton(
                                title: "Text",
                                systemImage: "message.fill",
                                url: phoneURL(scheme: "sms", number: trustedPhoneContact.phoneNumber)
                            )
                        }
                    } else {
                        supportPrompt(
                            systemImage: "person.crop.circle.badge.plus",
                            text: "Add one trusted contact to this plan while things are calm."
                        )
                    }

                    HStack(spacing: 8) {
                        crisisActionButton(
                            title: "Call 911",
                            systemImage: "phone.badge.waveform.fill",
                            url: URL(string: "tel:911"),
                            variant: .destructive
                        )

                        crisisActionButton(
                            title: "Text 988",
                            systemImage: "message.badge.fill",
                            url: URL(string: "sms:988")
                        )
                    }

                    crisisActionButton(
                        title: "988 Crisis Lifeline",
                        systemImage: "lifepreserver.fill",
                        url: URL(string: "https://988lifeline.org")
                    )

                    Button {
                        store.recordUsage("toolkit_need_help")
                        showingCopingPlan = true
                        refreshToken &+= 1
                    } label: {
                        Label("Open Rough Patch Plan", systemImage: "arrow.up.right.circle.fill")
                    }
                    .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: themeManager.selectedColor))

                    supportPrompt(
                        systemImage: "location.circle.fill",
                        text: "Emergency and crisis resources vary by location. Use your local emergency number if you are outside the U.S. or 911 is not appropriate where you are."
                    )
                }
            }
        }
    }

    private func crisisActionButton(
        title: String,
        systemImage: String,
        url: URL?,
        variant: DSButtonVariant = .secondary
    ) -> some View {
        Button {
            guard let url else { return }
            openURL(url)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(DSButtonStyle(variant: variant, size: .compact, tint: themeManager.selectedColor))
        .disabled(url == nil)
    }

    private func supportPrompt(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 18)
                .padding(.top, 1)

            Text(text)
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func contactName(_ contact: EmergencyContact) -> String {
        let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Contact" : name
    }

    private func phoneURL(scheme: String, number: String) -> URL? {
        let normalized = number.filter { $0.isNumber || $0 == "+" }
        guard !normalized.isEmpty else { return nil }
        return URL(string: "\(scheme):\(normalized)")
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "All", filter: nil)
                ForEach(CopingToolkitFilter.allCases) { filter in
                    filterButton(title: filter.title, filter: filter)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterButton(title: String, filter: CopingToolkitFilter?) -> some View {
        Button {
            selectedFilter = filter
            HapticManager.shared.selection()
        } label: {
            Text(title)
        }
        .buttonStyle(DSSelectionButtonStyle(isSelected: selectedFilter == filter, selectedColor: themeManager.selectedColor, size: .compact, expands: false))
    }

    private func toolSection(title: String, tools: [CopingToolkitTool]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
                .tracking(0.6)

            if tools.isEmpty {
                Text("No tools match this filter yet.")
                    .font(DSTypography.body)
                    .foregroundStyle(DSTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.paddingMedium)
                    .cardStyle()
            } else {
                VStack(spacing: 10) {
                    ForEach(tools) { tool in
                        CopingToolCard(
                            tool: tool,
                            isFavorite: store.isFavorite(tool.id),
                            isSavedToPlan: store.isInCopingPlan(tool.id),
                            onFavorite: {
                                _ = store.toggleFavorite(tool.id)
                                refreshToken &+= 1
                            },
                            onPlanToggle: {
                                toggleEmergencyKitTool(tool)
                                refreshToken &+= 1
                            },
                            onOpen: { open(tool) }
                        )
                    }
                }
            }
        }
    }

    private func emergencyKitSection(tools: [CopingToolkitTool]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Emergency Kit")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryText)
                    .tracking(0.6)

                Spacer()

                Text("\(tools.count)/\(store.maximumCopingPlanTools)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(themeManager.selectedColor)
            }

            Text("Pin 3-5 tools you trust for anxiety, sadness, anger, or overwhelm.")
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)

            VStack(spacing: 10) {
                ForEach(tools) { tool in
                    CopingToolCard(
                        tool: tool,
                        isFavorite: store.isFavorite(tool.id),
                        isSavedToPlan: store.isInCopingPlan(tool.id),
                        onFavorite: {
                            _ = store.toggleFavorite(tool.id)
                            refreshToken &+= 1
                        },
                        onPlanToggle: {
                            toggleEmergencyKitTool(tool)
                            refreshToken &+= 1
                        },
                        onOpen: { open(tool) }
                    )
                }
            }
        }
    }

    private var emergencyKitEmptyCard: some View {
        DSCardContainer {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "pin.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Build your Emergency Kit")
                        .font(DSTypography.cardTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    Text("Pin 3-5 tools you would want nearby during anxiety, sadness, anger, or overwhelm.")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(themeManager.selectedColor)
                .padding(.top, 2)

            Text("These tools are for self-guided emotional regulation and are not emergency care. If you may harm yourself or someone else, or you are in immediate danger, contact local emergency services or a crisis line now.")
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func open(_ tool: CopingToolkitTool) {
        store.recordUsage(tool.id)
        refreshToken &+= 1

        switch tool.destination {
        case .breathing(let seconds):
            BreathingPresenter.shared.present(durationSeconds: seconds, autoStart: true)
        case .exercise(let id):
            selectedExercise = ExerciseService.shared.exercise(withID: id)
        case .safety:
            showingCopingPlan = true
        }
    }

    private func toggleEmergencyKitTool(_ tool: CopingToolkitTool) {
        guard store.canAddCopingPlanTool(tool.id) else {
            showingEmergencyKitLimit = true
            return
        }
        _ = store.toggleCopingPlanTool(tool.id)
    }
}

struct CopingToolCard: View {
    @Environment(ThemeManager.self) private var themeManager

    let tool: CopingToolkitTool
    let isFavorite: Bool
    let isSavedToPlan: Bool
    let onFavorite: () -> Void
    let onPlanToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(themeManager.selectedColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(themeManager.selectedColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.title)
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(DSTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(tool.subtitle)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                    }
                    .buttonStyle(DSButtonStyle(variant: .neutral, size: .icon(34), expands: false, hapticType: .light))
                    .accessibilityLabel(isFavorite ? "Remove favorite" : "Favorite")
                }

                HStack(spacing: 8) {
                    Label(tool.durationLabel, systemImage: "clock")
                    Text(tool.kind)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                    Button(action: onPlanToggle) {
                        Image(systemName: isSavedToPlan ? "pin.fill" : "pin")
                    }
                    .buttonStyle(DSButtonStyle(variant: .neutral, size: .icon(34), expands: false, hapticType: .light))
                    .accessibilityLabel(isSavedToPlan ? "Remove from Emergency Kit" : "Pin to Emergency Kit")

                    Button(action: onOpen) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.selectedColor, hapticType: .light))
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
