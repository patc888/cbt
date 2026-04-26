import SwiftUI

struct SetupHeroSection: View {
    var selectedMode: AddTimeBlockView.EntryMode
    var category: TimeBlockCategory
    var selectedSetupIconSymbol: String
    var currentSetupAccentColor: Color
    var currentChooserTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(currentChooserTint.opacity(0.12))
                        .frame(width: 62, height: 62)

                    Image(systemName: selectedMode.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(currentChooserTint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Add to your day")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Start with a clean chooser, then continue into the right flow for a block, Brain Dump, or routine.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            HStack(spacing: 8) {
                setupStatPill(label: selectedMode.rawValue, icon: selectedMode.icon, tint: currentChooserTint)
                if selectedMode == .standard {
                    setupStatPill(label: category.title, icon: selectedSetupIconSymbol, tint: currentSetupAccentColor)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func setupStatPill(label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SetupModeSwitcherSection: View {
    @Binding var selectedMode: AddTimeBlockView.EntryMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeSectionHeader(
                "Create",
                subtitle: "Choose what you want the add flow to start with. New Block stays selected by default."
            )

            HStack(spacing: 10) {
                ForEach(AddTimeBlockView.EntryMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 14, weight: .bold))
                                Spacer(minLength: 0)
                                if selectedMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }

                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .bold, design: .rounded))

                            Text(mode.setupDescription)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(2)
                        }
                        .foregroundStyle(selectedMode == mode ? Color.white : Theme.primaryText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedMode == mode ? mode.modeTint : Color.primary.opacity(0.04))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(selectedMode == mode ? mode.modeTint.opacity(0.2) : Color.primary.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct RoutinesShortcutsSection: View {
    @Binding var isPresentingNewTemplateEditor: Bool
    var templates: [ScheduleTemplate]
    @Binding var editingTemplate: ScheduleTemplate?
    var onOpenFullSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Manage Routines")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                
                Spacer()
                
                Button {
                    isPresentingNewTemplateEditor = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Theme.primaryAccent)
            }
            .padding(.horizontal, 4)

            if templates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.primaryAccent.opacity(0.4))
                    
                    Text("No routines yet")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    
                    Text("Create reusable blocks that help you plan future days faster.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(templates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)
                                    
                                    Text("\(template.defaultDurationMinutes)m • \(template.category.title)")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Button {
                onOpenFullSettings()
            } label: {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open full Routine settings")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.primaryAccent.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
}

struct ChooserModeIntroCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

