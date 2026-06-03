import SwiftUI
import SwiftData
import os

struct NewThoughtRecordFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var viewModel = NewThoughtRecordViewModel()
    @State private var completedRecord: ThoughtRecord?
    @State private var hasCompletedGroundingPreparation: Bool
    private let recordID: PersistentIdentifier?

    init(recordID: PersistentIdentifier? = nil) {
        self.recordID = recordID
        _hasCompletedGroundingPreparation = State(initialValue: recordID != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let completedRecord {
                    ThoughtRecordNextStepView(record: completedRecord) {
                        dismiss()
                    }
                } else if !hasCompletedGroundingPreparation {
                    ThemedBackground().ignoresSafeArea()

                    VStack {
                        GroundingPreparationView(
                            title: String(localized: "Ground Before Thought Work"),
                            message: String(localized: "Thought records can ask you to look directly at a hard moment. You can take a 30-second breathing reset first, or begin when you feel ready."),
                            continueTitle: String(localized: "Start Thought Record")
                        ) {
                            hasCompletedGroundingPreparation = true
                        }
                        .padding(.horizontal, DSSpacing.large)
                        .responsiveMaxWidth()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ThemedBackground().ignoresSafeArea()

                    VStack(spacing: 0) {
                        Picker("Thought record mode", selection: $viewModel.mode) {
                            ForEach(ThoughtRecordMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, DSSpacing.large)
                        .padding(.top, DSSpacing.large)

                        VStack(alignment: .leading, spacing: DSSpacing.small) {
                            Text("Step \(viewModel.currentStep + 1) of \(viewModel.totalSteps)")
                                .font(DSTypography.caption)
                                .foregroundStyle(DSTheme.secondaryText)

                            ProgressView(value: Double(viewModel.currentStep + 1), total: Double(viewModel.totalSteps))
                                .tint(themeManager.selectedColor)
                                .accessibilityLabel("Step \(viewModel.currentStep + 1) of \(viewModel.totalSteps)")
                        }
                        .padding(.horizontal, DSSpacing.large)
                        .padding(.top, DSSpacing.medium)
                        .padding(.bottom, DSSpacing.small)

                        TabView(selection: $viewModel.currentStep) {
                            ForEach(Array(stepKinds.enumerated()), id: \.element) { index, step in
                                stepView(for: step).tag(index)
                            }
                        }
                        #if os(iOS)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        #endif
                        .animation(.easeInOut, value: viewModel.currentStep)

                        HStack(spacing: DSSpacing.medium) {
                            if viewModel.currentStep > 0 {
                                Button("Back") {
                                    HapticManager.shared.selection()
                                    moveToPreviousStep()
                                }
                                .buttonStyle(DSSecondaryButtonStyle())
                                .accessibilityLabel("Go back to previous step")
                            }

                            Spacer()

                            if viewModel.currentStep < viewModel.totalSteps - 1 {
                                let canProceed = viewModel.currentStep != 0 || viewModel.canSave
                                Button("Next") {
                                    HapticManager.shared.selection()
                                    moveToNextStep()
                                }
                                .buttonStyle(DSPrimaryButtonStyle())
                                .disabled(!canProceed)
                                .accessibilityLabel("Go to next step")
                            } else {
                                Button("Save") {
                                    HapticManager.shared.success()
                                    if let record = viewModel.saveRecord(context: modelContext) {
                                        ReviewManager.shared.logSignificantAction()
                                        completedRecord = record
                                    }
                                }
                                .buttonStyle(DSPrimaryButtonStyle())
                                .disabled(!viewModel.canSave)
                            }
                        }
                        .padding(.horizontal, DSSpacing.large)
                        .padding(.top, DSSpacing.small)

                        ThoughtRecordNotReadyActions(
                            canSkipDetails: viewModel.canSave,
                            skipDetails: savePartialRecord,
                            comeBackLater: { dismiss() },
                            resetInstead: { viewModel.showBreathing = true }
                        )
                        .padding(.horizontal, DSSpacing.large)
                        .padding(.top, 2)
                        .padding(.bottom, DSSpacing.large)
                        .background(DSTheme.cardBackground.ignoresSafeArea(edges: .bottom))
                    }
                }
            }
            .navigationTitle(completedRecord == nil ? "New Thought Record" : "Next Step")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if completedRecord == nil {
                        #if targetEnvironment(macCatalyst)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(.title3, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .accessibilityLabel("Cancel")
                        #else
                        Button("Cancel") {
                            dismiss()
                        }
                        #endif
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                loadExistingRecordIfNeeded()
            }
            .onChange(of: viewModel.mode) { _, _ in
                viewModel.currentStep = min(viewModel.currentStep, viewModel.totalSteps - 1)
                viewModel.saveDraft(context: modelContext)
            }
            .onChange(of: viewModel.draftSignature) { _, _ in
                viewModel.saveDraft(context: modelContext)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $viewModel.showBreathing) {
                NavigationStack {
                    BreathingResetView(
                        durationSeconds: 60,
                        pattern: .box,
                        autoStart: true,
                        showsDismissControl: true,
                        showControls: true,
                        hideBackground: false,
                        onComplete: nil,
                        onDismiss: { viewModel.showBreathing = false }
                    )
                }
            }
            #else
            .sheet(isPresented: $viewModel.showBreathing) {
                NavigationStack {
                    BreathingResetView(
                        durationSeconds: 60,
                        pattern: .box,
                        autoStart: true,
                        showsDismissControl: true,
                        showControls: true,
                        hideBackground: false,
                        onComplete: nil,
                        onDismiss: { viewModel.showBreathing = false }
                    )
                }
                .dsSheetPresentation()
            }
            #endif
        }
    }

    private func moveToPreviousStep() {
        guard viewModel.currentStep > 0 else { return }
        withAnimation {
            viewModel.currentStep = max(0, viewModel.currentStep - 1)
        }
    }

    private func moveToNextStep() {
        guard viewModel.currentStep < viewModel.totalSteps - 1 else { return }
        withAnimation {
            viewModel.currentStep = min(viewModel.totalSteps - 1, viewModel.currentStep + 1)
        }
    }

    private func savePartialRecord() {
        guard let record = viewModel.saveRecord(context: modelContext) else { return }
        ReviewManager.shared.logSignificantAction()
        HapticManager.shared.success()
        completedRecord = record
    }

    private var stepKinds: [ThoughtRecordStepKind] {
        if viewModel.mode == .quick {
            return [.context, .emotion, .distortion, .balanced]
        }
        return [.context, .emotion, .distortion, .evidence, .balanced]
    }

    @ViewBuilder
    private func stepView(for step: ThoughtRecordStepKind) -> some View {
        switch step {
        case .context:
            ContextStepView(viewModel: viewModel)
        case .emotion:
            EmotionStepView(viewModel: viewModel)
        case .distortion:
            DistortionStepView(viewModel: viewModel)
        case .evidence:
            EvidenceStepView(viewModel: viewModel)
        case .balanced:
            BalancedStepView(viewModel: viewModel)
        }
    }

    @MainActor
    private func loadExistingRecordIfNeeded() {
        guard viewModel.draftRecord == nil else {
            return
        }

        if let recordID, let record = modelContext.model(for: recordID) as? ThoughtRecord {
            viewModel.load(record: record)
            return
        }

        do {
            var descriptor = FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { record in
                    record.isDeleted == false && record.isDraft == true
                },
                sortBy: [SortDescriptor(\ThoughtRecord.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            if let draft = try modelContext.fetch(descriptor).first {
                viewModel.load(record: draft)
            }
        } catch {
            AppLogger.make(category: "Data").error("Failed to load thought record draft: \(error.localizedDescription, privacy: .private)")
        }
    }
}

private enum ThoughtRecordStepKind: Hashable {
    case context
    case emotion
    case distortion
    case evidence
    case balanced
}

private struct ThoughtRecordNotReadyActions: View {
    @Environment(ThemeManager.self) private var themeManager
    let canSkipDetails: Bool
    let skipDetails: () -> Void
    let comeBackLater: () -> Void
    let resetInstead: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                actions
            }

            VStack(spacing: 10) {
                actions
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button {
            skipDetails()
        } label: {
            Label("Skip details", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))
        .disabled(!canSkipDetails)

        Button {
            resetInstead()
        } label: {
            Label("Do a 60-second reset instead", systemImage: "wind")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))

        Button {
            comeBackLater()
        } label: {
            Label("Come back later", systemImage: "clock")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))
    }
}
