import SwiftUI

struct TimeBlockSuggestion: Identifiable {
    let id: String
    let title: String
    let category: TimeBlockCategory
    let durationMinutes: Int
    let notes: String

    init(
        title: String,
        category: TimeBlockCategory,
        durationMinutes: Int,
        notes: String
    ) {
        self.id = title
        self.title = title
        self.category = category
        self.durationMinutes = durationMinutes
        self.notes = notes
    }
}

struct SetupIconOption: Identifiable {
    let id: String
    let symbolName: String
    let title: String
    let category: TimeBlockCategory
}

struct SetupAccentOption: Identifiable {
    let id: String
    let title: String
    let tintColor: Color
    let category: TimeBlockCategory
}

struct SuggestionGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let suggestions: [TimeBlockSuggestion]
}

extension AddTimeBlockView {
    static func defaultSetupIconSymbol(for category: TimeBlockCategory) -> String {
        switch category {
        case .focus: return "scope"
        case .personal: return "figure.walk"
        case .admin: return "tray.full.fill"
        case .routine: return "repeat"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    static func defaultSetupAccentID(for category: TimeBlockCategory) -> String {
        switch category {
        case .focus: return "focus-violet"
        case .personal: return "personal-amber"
        case .admin: return "admin-sky"
        case .routine: return "routine-mint"
        case .custom: return "custom-indigo"
        }
    }

    var setupIconOptions: [SetupIconOption] {
        [
            SetupIconOption(id: "scope", symbolName: "scope", title: "Focus", category: .focus),
            SetupIconOption(id: "laptopcomputer", symbolName: "laptopcomputer", title: "Laptop", category: .focus),
            SetupIconOption(id: "doc.text.fill", symbolName: "doc.text.fill", title: "Write", category: .focus),
            SetupIconOption(id: "chart.bar.fill", symbolName: "chart.bar.fill", title: "Plan", category: .focus),
            SetupIconOption(id: "lightbulb.fill", symbolName: "lightbulb.fill", title: "Ideas", category: .focus),
            SetupIconOption(id: "tray.full.fill", symbolName: "tray.full.fill", title: "Admin", category: .admin),
            SetupIconOption(id: "calendar.badge.clock", symbolName: "calendar.badge.clock", title: "Calendar", category: .admin),
            SetupIconOption(id: "envelope.fill", symbolName: "envelope.fill", title: "Email", category: .admin),
            SetupIconOption(id: "creditcard.fill", symbolName: "creditcard.fill", title: "Bills", category: .admin),
            SetupIconOption(id: "folder.fill", symbolName: "folder.fill", title: "Files", category: .admin),
            SetupIconOption(id: "figure.walk", symbolName: "figure.walk", title: "Walk", category: .personal),
            SetupIconOption(id: "heart.fill", symbolName: "heart.fill", title: "Health", category: .personal),
            SetupIconOption(id: "cart.fill", symbolName: "cart.fill", title: "Errands", category: .personal),
            SetupIconOption(id: "dumbbell.fill", symbolName: "dumbbell.fill", title: "Workout", category: .personal),
            SetupIconOption(id: "fork.knife", symbolName: "fork.knife", title: "Meals", category: .personal),
            SetupIconOption(id: "repeat", symbolName: "repeat", title: "Repeat", category: .routine),
            SetupIconOption(id: "sunrise.fill", symbolName: "sunrise.fill", title: "Morning", category: .routine),
            SetupIconOption(id: "moon.stars.fill", symbolName: "moon.stars.fill", title: "Evening", category: .routine),
            SetupIconOption(id: "alarm.fill", symbolName: "alarm.fill", title: "Habit", category: .routine),
            SetupIconOption(id: "checkmark.circle.fill", symbolName: "checkmark.circle.fill", title: "Reset", category: .routine),
            SetupIconOption(id: "square.grid.2x2.fill", symbolName: "square.grid.2x2.fill", title: "General", category: .custom),
            SetupIconOption(id: "sparkles", symbolName: "sparkles", title: "Fresh", category: .custom),
            SetupIconOption(id: "flag.fill", symbolName: "flag.fill", title: "Priority", category: .custom),
            SetupIconOption(id: "bookmark.fill", symbolName: "bookmark.fill", title: "Keep", category: .custom),
            SetupIconOption(id: "bolt.fill", symbolName: "bolt.fill", title: "Quick", category: .custom)
        ]
    }

    var setupAccentOptions: [SetupAccentOption] {
        [
            SetupAccentOption(id: "focus-violet", title: "Violet", tintColor: Theme.primaryAccent, category: .focus),
            SetupAccentOption(id: "focus-indigo", title: "Indigo", tintColor: Color(hex: "6366F1"), category: .focus),
            SetupAccentOption(id: "admin-sky", title: "Sky", tintColor: Color(hex: "0EA5E9"), category: .admin),
            SetupAccentOption(id: "admin-cobalt", title: "Cobalt", tintColor: Color(hex: "2563EB"), category: .admin),
            SetupAccentOption(id: "personal-amber", title: "Amber", tintColor: Color(hex: "F59E0B"), category: .personal),
            SetupAccentOption(id: "personal-coral", title: "Coral", tintColor: Color(hex: "F97316"), category: .personal),
            SetupAccentOption(id: "routine-mint", title: "Mint", tintColor: Color(hex: "10B981"), category: .routine),
            SetupAccentOption(id: "routine-teal", title: "Teal", tintColor: Color(hex: "14B8A6"), category: .routine),
            SetupAccentOption(id: "custom-indigo", title: "Indigo", tintColor: Color(hex: "6366F1"), category: .custom),
            SetupAccentOption(id: "custom-fuchsia", title: "Fuchsia", tintColor: Color(hex: "E879F9"), category: .custom)
        ]
    }

    var suggestionGroups: [SuggestionGroup] {
        [
            SuggestionGroup(
                id: "focus",
                title: "Focus Blocks",
                subtitle: "Protected work and meaningful progress",
                suggestions: suggestions.filter { $0.category == .focus }.prefix(6).map { $0 }
            ),
            SuggestionGroup(
                id: "admin",
                title: "Life Admin",
                subtitle: "Small tasks that deserve a home on the calendar",
                suggestions: suggestions.filter { $0.category == .admin }.prefix(6).map { $0 }
            ),
            SuggestionGroup(
                id: "personal",
                title: "Personal Time",
                subtitle: "Health, errands, and home rhythms",
                suggestions: suggestions.filter { $0.category == .personal }.prefix(6).map { $0 }
            ),
            SuggestionGroup(
                id: "routine",
                title: "Repeatable Anchors",
                subtitle: "Reliable planning rituals and resets",
                suggestions: suggestions.filter { $0.category == .routine }.prefix(6).map { $0 }
            )
        ]
    }

    var suggestions: [TimeBlockSuggestion] {
        [
            TimeBlockSuggestion(title: "Client Project Focus", category: .focus, durationMinutes: 90, notes: "Dedicated time for high-leverage client deliverables."),
            TimeBlockSuggestion(title: "Strategic Planning", category: .focus, durationMinutes: 60, notes: "Reviewing business goals and aligning next actions."),
            TimeBlockSuggestion(title: "Content Creation", category: .focus, durationMinutes: 75, notes: "Drafting social posts, articles, or marketing materials."),
            TimeBlockSuggestion(title: "Proposal Writing", category: .focus, durationMinutes: 60, notes: "Putting together details and pricing for new opportunities."),
            TimeBlockSuggestion(title: "Sales Outreach", category: .focus, durationMinutes: 45, notes: "Connecting with leads and following up on inquiries."),
            TimeBlockSuggestion(title: "Deep Work Sprint", category: .focus, durationMinutes: 120, notes: "No distractions. Phone away. Pure concentration."),
            TimeBlockSuggestion(title: "Product Development", category: .focus, durationMinutes: 90, notes: "Working on the core offering or new service lines."),
            TimeBlockSuggestion(title: "Website Updates", category: .focus, durationMinutes: 60, notes: "Polishing the digital storefront and checking links."),
            TimeBlockSuggestion(title: "Portfolio Refresh", category: .focus, durationMinutes: 75, notes: "Updating recent work to showcase to new clients."),
            TimeBlockSuggestion(title: "Skill Building", category: .focus, durationMinutes: 60, notes: "Learning something new to improve the business."),
            TimeBlockSuggestion(title: "Market Research", category: .focus, durationMinutes: 45, notes: "Seeing what else is happening in the industry."),
            TimeBlockSuggestion(title: "Creative Exploration", category: .focus, durationMinutes: 90, notes: "Playing with new ideas without immediate pressure."),
            TimeBlockSuggestion(title: "Inbox Management", category: .admin, durationMinutes: 30, notes: "Processing emails, setting appointments, and clearing clutter."),
            TimeBlockSuggestion(title: "Invoicing & Billing", category: .admin, durationMinutes: 20, notes: "Sending out bills and following up on payments."),
            TimeBlockSuggestion(title: "Expense Tracking", category: .admin, durationMinutes: 20, notes: "Recording receipts and staying on top of the books."),
            TimeBlockSuggestion(title: "Schedule Buffer", category: .admin, durationMinutes: 15, notes: "Space between calls or tasks to catch your breath."),
            TimeBlockSuggestion(title: "File Organization", category: .admin, durationMinutes: 30, notes: "Cleaning up the desktop and cloud storage."),
            TimeBlockSuggestion(title: "Call Logistics", category: .admin, durationMinutes: 20, notes: "Confirming times and sending meeting links."),
            TimeBlockSuggestion(title: "Social Media Triage", category: .admin, durationMinutes: 25, notes: "Replying to comments and managing notifications."),
            TimeBlockSuggestion(title: "Ordering Supplies", category: .admin, durationMinutes: 15, notes: "Restocking the essentials for the workspace."),
            TimeBlockSuggestion(title: "Legal & Insurance", category: .admin, durationMinutes: 45, notes: "Reviewing contracts or managing policy updates."),
            TimeBlockSuggestion(title: "Bank Run", category: .admin, durationMinutes: 30, notes: "Handling physical errands for the business."),
            TimeBlockSuggestion(title: "Afternoon Reset", category: .personal, durationMinutes: 20, notes: "A quick break to step away from the screen."),
            TimeBlockSuggestion(title: "Physical Movement", category: .personal, durationMinutes: 45, notes: "Getting some activity in to keep energy high."),
            TimeBlockSuggestion(title: "Quick Errand", category: .personal, durationMinutes: 30, notes: "Handling a small personal task in the neighborhood."),
            TimeBlockSuggestion(title: "Family Dinner", category: .personal, durationMinutes: 90, notes: "Time to disconnect and be present at home."),
            TimeBlockSuggestion(title: "Coffee Break", category: .personal, durationMinutes: 15, notes: "A short pause for a beverage and a breather."),
            TimeBlockSuggestion(title: "Lunch Break", category: .personal, durationMinutes: 45, notes: "Fueling up away from the desk."),
            TimeBlockSuggestion(title: "Reading Break", category: .personal, durationMinutes: 20, notes: "Stepping into another world for a few minutes."),
            TimeBlockSuggestion(title: "Evening Wind Down", category: .personal, durationMinutes: 60, notes: "Relaxing activities before ending the day."),
            TimeBlockSuggestion(title: "Daily Strategy", category: .routine, durationMinutes: 20, notes: "Setting the agenda and identifying the one big thing."),
            TimeBlockSuggestion(title: "Weekly Reflection", category: .routine, durationMinutes: 60, notes: "Looking back at progress and planning the next 7 days."),
            TimeBlockSuggestion(title: "Shutdown Ritual", category: .routine, durationMinutes: 15, notes: "Closing loops and preparing the desk for tomorrow."),
            TimeBlockSuggestion(title: "Morning Routine", category: .routine, durationMinutes: 45, notes: "Getting the day started on the right foot."),
            TimeBlockSuggestion(title: "Daily Planning", category: .routine, durationMinutes: 10, notes: "A quick check of the calendar and priorities."),
            TimeBlockSuggestion(title: "Month-End Review", category: .routine, durationMinutes: 90, notes: "Assessing the bigger picture and finances."),
            TimeBlockSuggestion(title: "Sunday Prep", category: .routine, durationMinutes: 30, notes: "Setting the stage for a productive week ahead."),
            TimeBlockSuggestion(title: "Brain Dump", category: .custom, durationMinutes: 20, notes: "Getting everything out of your head and onto the list."),
            TimeBlockSuggestion(title: "Transition Time", category: .custom, durationMinutes: 15, notes: "Buffer space to switch gears between contexts."),
            TimeBlockSuggestion(title: "Open Space", category: .custom, durationMinutes: 45, notes: "A flexible block for whatever needs attention most.")
        ]
    }
}

extension TimeBlockCategory {
    var symbolName: String {
        switch self {
        case .focus:
            "scope"
        case .personal:
            "figure.walk"
        case .admin:
            "tray.full.fill"
        case .routine:
            "repeat"
        case .custom:
            "square.grid.2x2.fill"
        }
    }

    var colorLabel: String {
        switch self {
        case .focus:
            "Purple"
        case .personal:
            "Amber"
        case .admin:
            "Blue"
        case .routine:
            "Green"
        case .custom:
            "Indigo"
        }
    }

    var tintColor: Color {
        switch self {
        case .focus:
            Theme.primaryAccent
        case .personal:
            Color(hex: "F59E0B")
        case .admin:
            Color(hex: "0EA5E9")
        case .routine:
            Color(hex: "10B981")
        case .custom:
            Color(hex: "6366F1")
        }
    }
}

