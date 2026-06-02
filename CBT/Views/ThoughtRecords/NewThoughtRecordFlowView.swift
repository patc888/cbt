import SwiftUI
import SwiftData
import os

struct NewThoughtRecordFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var viewModel = NewThoughtRecordViewModel()
    @State private var completedRecord: ThoughtRecord?

    var body: some View {
        NavigationStack {
            ZStack {
                if let completedRecord {
                    ThoughtRecordNextStepView(record: completedRecord) {
                        dismiss()
                    }
                } else {
                    ThemedBackground().ignoresSafeArea()

                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: DSSpacing.small) {
                            Text("Step \(viewModel.currentStep + 1) of \(viewModel.totalSteps)")
                                .font(DSTypography.caption)
                                .foregroundStyle(DSTheme.secondaryText)

                            ProgressView(value: Double(viewModel.currentStep + 1), total: Double(viewModel.totalSteps))
                                .tint(themeManager.selectedColor)
                                .accessibilityLabel("Step \(viewModel.currentStep + 1) of \(viewModel.totalSteps)")
                        }
                        .padding(.horizontal, DSSpacing.large)
                        .padding(.top, DSSpacing.large)
                        .padding(.bottom, DSSpacing.small)

                        TabView(selection: $viewModel.currentStep) {
                            ContextStepView(viewModel: viewModel).tag(0)
                            EmotionStepView(viewModel: viewModel).tag(1)
                            DistortionStepView(viewModel: viewModel).tag(2)
                            EvidenceStepView(viewModel: viewModel).tag(3)
                            BalancedStepView(viewModel: viewModel).tag(4)
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
}
