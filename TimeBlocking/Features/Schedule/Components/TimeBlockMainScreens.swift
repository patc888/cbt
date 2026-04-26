import SwiftUI

struct SetupChooserScreen<
    Hero: View,
    Switcher: View,
    StandardContent: View,
    BrainDumpContent: View,
    RoutinesContent: View
>: View {
    @Binding var selectedMode: AddTimeBlockView.EntryMode
    var dismissAction: () -> Void

    @ViewBuilder var heroSection: Hero
    @ViewBuilder var switcherSection: Switcher
    @ViewBuilder var standardContent: StandardContent
    @ViewBuilder var brainDumpContent: BrainDumpContent
    @ViewBuilder var routinesContent: RoutinesContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection

                TimeCard {
                    VStack(alignment: .leading, spacing: 24) {
                        switcherSection

                        Divider()

                        switch selectedMode {
                        case .standard:
                            standardContent
                        case .brainDump:
                            brainDumpContent
                        case .routines:
                            routinesContent
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .navigationTitle("Add")
        .timeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismissAction()
                }
            }
        }
    }
}

struct BlockEditorScreen<
    RoutinesContent: View,
    BrainDumpCaptureContent: View,
    BrainDumpContent: View,
    SchedulingContent: View,
    ChecklistContent: View
>: View {
    let sectionTitle: String
    let subtitle: String
    let isEditing: Bool
    let isBlockMissing: Bool
    let showsEntryModePicker: Bool
    @Binding var selectedMode: AddTimeBlockView.EntryMode
    let showsBrainDumpFirst: Bool
    let errorMessage: String?
    @Binding var isShowingDeleteConfirmation: Bool
    let editorNavigationTitle: String
    let startsWithSetupScreen: Bool
    let saveButtonTitle: String
    let isSaveDisabled: Bool

    let dismissAction: () -> Void
    let saveBrainDumpAction: () -> Void
    let saveBlockAction: () -> Void
    
    @ViewBuilder var routinesContent: RoutinesContent
    @ViewBuilder var brainDumpCaptureContent: BrainDumpCaptureContent
    @ViewBuilder var brainDumpContent: BrainDumpContent
    @ViewBuilder var schedulingContent: SchedulingContent
    @ViewBuilder var checklistContent: ChecklistContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TimeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        TimeSectionHeader(
                            sectionTitle,
                            subtitle: subtitle
                        )

                        if isBlockMissing {
                            Text("This time block is no longer available. Close this sheet and reopen the block from the schedule.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            if showsEntryModePicker {
                                Picker("Entry Mode", selection: $selectedMode) {
                                    ForEach(AddTimeBlockView.EntryMode.allCases) { mode in
                                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.bottom, 8)

                                Divider()
                                    .padding(.bottom, 16)
                            }

                            if selectedMode == .routines {
                                routinesContent
                            } else if !isEditing && selectedMode == .brainDump {
                                brainDumpCaptureContent
                            } else {
                                if showsBrainDumpFirst {
                                    brainDumpContent

                                    Divider()
                                        .padding(.vertical, 4)

                                    schedulingContent
                                } else {
                                    schedulingContent

                                    Divider()
                                        .padding(.vertical, 4)

                                    brainDumpContent
                                }
                            }

                            if !isEditing && selectedMode != .brainDump {
                                Text("Use Routines for plans you want regenerated later. Manual blocks are for one-off plans and personal adjustments.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }

                if selectedMode != .brainDump || isEditing {
                    TimeCard {
                        checklistContent
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if isEditing {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Text("Delete Time Block")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.red)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isBlockMissing)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .navigationTitle(editorNavigationTitle)
        .timeInlineNavigationTitle()
        .toolbar {
            if !startsWithSetupScreen {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissAction()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if selectedMode != .routines {
                    Button(saveButtonTitle) {
                        if !isEditing && selectedMode == .brainDump {
                            saveBrainDumpAction()
                        } else {
                            saveBlockAction()
                        }
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}
