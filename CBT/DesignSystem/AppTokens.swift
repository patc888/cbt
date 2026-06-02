import SwiftUI

enum AppTokens {
    struct ColorPalette {
        let primary: Color
        let secondary: Color
    }

    struct Theme {
        static var cyan: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.cyan.primaryHex), secondary: Color(hex: AppColorTheme.cyan.secondaryHex))
        }

        static var blue: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.blue.primaryHex), secondary: Color(hex: AppColorTheme.blue.secondaryHex))
        }

        static var purple: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.purple.primaryHex), secondary: Color(hex: AppColorTheme.purple.secondaryHex))
        }

        static var pink: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.pink.primaryHex), secondary: Color(hex: AppColorTheme.pink.secondaryHex))
        }

        static var orange: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.orange.primaryHex), secondary: Color(hex: AppColorTheme.orange.secondaryHex))
        }

        static var emerald: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.emerald.primaryHex), secondary: Color(hex: AppColorTheme.emerald.secondaryHex))
        }

        static var gold: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.gold.primaryHex), secondary: Color(hex: AppColorTheme.gold.secondaryHex))
        }

        static var red: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.red.primaryHex), secondary: Color(hex: AppColorTheme.red.secondaryHex))
        }

        static var indigo: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.indigo.primaryHex), secondary: Color(hex: AppColorTheme.indigo.secondaryHex))
        }

        static var teal: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.teal.primaryHex), secondary: Color(hex: AppColorTheme.teal.secondaryHex))
        }

        static var mint: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.mint.primaryHex), secondary: Color(hex: AppColorTheme.mint.secondaryHex))
        }

        static var rose: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.rose.primaryHex), secondary: Color(hex: AppColorTheme.rose.secondaryHex))
        }

        static var coral: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.coral.primaryHex), secondary: Color(hex: AppColorTheme.coral.secondaryHex))
        }

        static var lavender: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.lavender.primaryHex), secondary: Color(hex: AppColorTheme.lavender.secondaryHex))
        }

        static var lime: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.lime.primaryHex), secondary: Color(hex: AppColorTheme.lime.secondaryHex))
        }

        static var graphite: ColorPalette {
            ColorPalette(primary: Color(hex: AppColorTheme.graphite.primaryHex), secondary: Color(hex: AppColorTheme.graphite.secondaryHex))
        }

        static var primaryText: Color { .primary }
        static var secondaryText: Color { .secondary }
        static var tertiaryText: Color { .secondary }

        #if canImport(UIKit)
        static var background: Color { Color(UIColor.secondarySystemBackground) }
        static var cardBackground: Color { Color(UIColor.systemBackground) }
        static var elevatedFill: Color { Color(UIColor.tertiarySystemFill) }
        #elseif canImport(AppKit)
        static var background: Color { Color(resolvedNSColor: .windowBackgroundColor) }
        static var cardBackground: Color { Color(resolvedNSColor: .controlBackgroundColor) }
        static var elevatedFill: Color { Color(resolvedNSColor: .quaternaryLabelColor).opacity(0.14) }
        #else
        static var background: Color { Color.secondary.opacity(0.1) }
        static var cardBackground: Color { Color.primary.opacity(0.05) }
        static var elevatedFill: Color { Color.primary.opacity(0.1) }
        #endif

        static var separator: Color { Color.secondary.opacity(0.16) }
        static var success: Color { .green }
        static var warning: Color { .orange }
        static var destructive: Color { .red }
        static var cardMaterial: Material { .regularMaterial }
    }

    struct Spacing {
        static var xs: CGFloat { 4 }
        static var sm: CGFloat { 8 }
        static var md: CGFloat { 12 }
        static var lg: CGFloat { 16 }
        static var xl: CGFloat { 24 }
        static var xxl: CGFloat { 28 }
        static var xxxl: CGFloat { 32 }
    }

    enum Typography {
        case pageTitle
        case headerTitle
        case sectionTitle
        case sectionHeader
        case listLabel
        case cardTitle
        case metricValue
        case journalBody
        case body
        case caption
        case button

        var font: Font {
            switch self {
            case .pageTitle:
                return .system(.largeTitle, design: .rounded).weight(.bold)
            case .headerTitle:
                return .system(size: 24, weight: .bold, design: .rounded)
            case .sectionTitle:
                return .system(.title2, design: .rounded).weight(.bold)
            case .sectionHeader:
                return .system(size: 25, weight: .bold, design: .rounded)
            case .listLabel:
                return .system(size: 16, weight: .medium, design: .rounded)
            case .cardTitle:
                return .system(.caption, design: .rounded).weight(.heavy)
            case .metricValue:
                return .system(.title2, design: .rounded).weight(.bold)
            case .journalBody:
                return .system(.body, design: .rounded)
            case .body:
                return .system(.body, design: .rounded)
            case .caption:
                return .system(.caption, design: .rounded).weight(.medium)
            case .button:
                return .system(.headline, design: .rounded)
            }
        }
    }

    static let viewMigrationTodo = [
        "CBT/Views/About/Components/BalancedEducationPage.swift",
        "CBT/Views/About/Components/ConclusionEducationPage.swift",
        "CBT/Views/About/Components/CycleEducationPage.swift",
        "CBT/Views/About/Components/DistortionButton.swift",
        "CBT/Views/About/Components/DistortionsEducationPage.swift",
        "CBT/Views/About/Components/EvidenceEducationPage.swift",
        "CBT/Views/About/Components/FurtherReadingEducationPage.swift",
        "CBT/Views/About/Components/IntroEducationPage.swift",
        "CBT/Views/About/Components/PagerLayout.swift",
        "CBT/Views/About/Components/ResearchEducationPage.swift",
        "CBT/Views/About/Components/ThoughtRecordEducationPage.swift",
        "CBT/Views/About/Components/TriangleEducationPage.swift",
        "CBT/Views/About/WhatIsCBTPagerView.swift",
        "CBT/Views/AppRoot/ContentView.swift",
        "CBT/Views/AppRoot/RootTabView.swift",
        "CBT/Views/AppStates/DeferredRenderView.swift",
        "CBT/Views/Assessments/AssessmentsView.swift",
        "CBT/Views/Assessments/PersonalityAssessmentView.swift",
        "CBT/Views/Breathing/BreathingControlsBar.swift",
        "CBT/Views/Breathing/BreathingEngine.swift",
        "CBT/Views/Breathing/BreathingOrbView.swift",
        "CBT/Views/Breathing/BreathingPattern.swift",
        "CBT/Views/Breathing/BreathingResetView.swift",
        "CBT/Views/Exercises/Affirmations/AffirmationCardView.swift",
        "CBT/Views/Exercises/Affirmations/AffirmationFavoritesStore.swift",
        "CBT/Views/Exercises/Affirmations/AffirmationPlayerView.swift",
        "CBT/Views/Exercises/BehavioralActivation/ActivityCompletionView.swift",
        "CBT/Views/Exercises/BehavioralActivation/ActivityPlannerView.swift",
        "CBT/Views/Exercises/BehavioralActivation/AddActivityView.swift",
        "CBT/Views/Exercises/Distortions/DistortionExampleCardView.swift",
        "CBT/Views/Exercises/Distortions/DistortionExamplesView.swift",
        "CBT/Views/Exercises/ExerciseCategoryView.swift",
        "CBT/Views/Exercises/ExerciseDetailComponents.swift",
        "CBT/Views/Exercises/ExerciseDetailView.swift",
        "CBT/Views/Exercises/ExercisesView.swift",
        "CBT/Views/Exercises/ExercisesViewModel.swift",
        "CBT/Views/Export/PDFReportView.swift",
        "CBT/Views/Home/DailyPlanView.swift",
        "CBT/Views/Home/HomeDashboardViewModel.swift",
        "CBT/Views/Home/HomeView.swift",
        "CBT/Views/Home/TipOfTheDayModal.swift",
        "CBT/Views/Insights/InsightsModels.swift",
        "CBT/Views/Insights/InsightsView.swift",
        "CBT/Views/Insights/InsightsViewModel.swift",
        "CBT/Views/Journal/GuidedJournalPickerView.swift",
        "CBT/Views/Journal/GuidedJournalWizardView.swift",
        "CBT/Views/Journal/JournalSessionRow.swift",
        "CBT/Views/Journal/JournalSessionsListView.swift",
        "CBT/Views/Journal/JournalView.swift",
        "CBT/Views/LockView.swift",
        "CBT/Views/Mood/MoodDetailView.swift",
        "CBT/Views/Mood/MoodListView.swift",
        "CBT/Views/MoodCheckin/EmotionSelectorView.swift",
        "CBT/Views/MoodCheckin/MoodCheckinSummaryView.swift",
        "CBT/Views/MoodCheckin/MoodCheckinView.swift",
        "CBT/Views/MoodCheckin/MoodColorSelector.swift",
        "CBT/Views/MoodCheckin/MoodIntensitySelector.swift",
        "CBT/Views/MoodCheckin/MoodNotesView.swift",
        "CBT/Views/MoodCheckin/MoodSuggestionsView.swift",
        "CBT/Views/MoodCheckin/MoodTriggerSelector.swift",
        "CBT/Views/Programs/ProgramDetailView.swift",
        "CBT/Views/Settings/AboutSettingsView.swift",
        "CBT/Views/Settings/AdvancedRemindersView.swift",
        "CBT/Views/Settings/AppearanceSettingsView.swift",
        "CBT/Views/Settings/DataResetOptionsView.swift",
        "CBT/Views/Settings/DataSettingsView.swift",
        "CBT/Views/Settings/LegalView.swift",
        "CBT/Views/Settings/RemindersSettingsSection.swift",
        "CBT/Views/Settings/SecuritySettingsView.swift",
        "CBT/Views/Settings/SettingsView.swift",
        "CBT/Views/Settings/SubscriptionSettingsView.swift",
        "CBT/Views/Settings/SyncStatusView.swift",
        "CBT/Views/Settings/ViewModels/AdvancedDataSettingsViewModel.swift",
        "CBT/Views/Settings/ViewModels/SettingsViewModel.swift",
        "CBT/Views/Subscription/SubscriptionView.swift",
        "CBT/Views/ThoughtRecords/NewThoughtRecordFlowView.swift",
        "CBT/Views/ThoughtRecords/NewThoughtRecordViewModel.swift",
        "CBT/Views/ThoughtRecords/Steps/BalancedStepView.swift",
        "CBT/Views/ThoughtRecords/Steps/ContextStepView.swift",
        "CBT/Views/ThoughtRecords/Steps/DistortionStepView.swift",
        "CBT/Views/ThoughtRecords/Steps/EmotionStepView.swift",
        "CBT/Views/ThoughtRecords/Steps/EvidenceStepView.swift",
        "CBT/Views/ThoughtRecords/ThoughtRecordDetailView.swift",
        "CBT/Views/ThoughtRecords/ThoughtRecordListView.swift",
        "CBT/Views/Timeline/TimelineItem.swift",
        "CBT/Views/Timeline/TimelineRouteDestinationView.swift",
        "CBT/Views/Timeline/TimelineRow.swift",
        "CBT/Views/Timeline/TimelineView.swift",
        "CBT/Views/Timeline/TimelineViewModel.swift",
        "CBT/Views/TimedSession/JournalEntryDetailView.swift",
        "CBT/Views/TimedSession/SaveSessionView.swift",
        "CBT/Views/TimedSession/SessionSummary.swift",
        "CBT/Views/TimedSession/TimedSessionSheet.swift"
    ]
}
