import SwiftUI
import SwiftData

struct JournalView: View {
    enum JournalTab: String, CaseIterable, Identifiable {
        case mood = "Mood"
        case thoughts = "Thoughts"
        case sessions = "Sessions"

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .mood: return String(localized: "Mood")
            case .thoughts: return String(localized: "Thoughts")
            case .sessions: return String(localized: "Sessions")
            }
        }

        var subtitle: String {
            switch self {
            case .mood:
                return String(localized: "Quick check-ins to track your emotional patterns.")
            case .thoughts:
                return String(localized: "Capture situations and reframe automatic thoughts.")
            case .sessions:
                return String(localized: "Timed practice sessions from exercises and tools.")
            }
        }

        var icon: String {
            switch self {
            case .mood:
                return "face.smiling"
            case .thoughts:
                return "brain.head.profile"
            case .sessions:
                return "book.pages"
            }
        }
    }
    @State private var selectedTab: JournalTab = .mood
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    TopHeadlineView(
                        title: String(localized: "Journal"),
                        subtitle: String(localized: "Track mood and thoughts in one place")
                    )

                    SegmentedToggle(
                        selection: $selectedTab,
                        options: JournalTab.allCases,
                        titleKey: \.localizedName
                    )

                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.primaryColor)
                        Text(selectedTab.subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.secondaryText.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)

                switch selectedTab {
                case .mood:
                    MoodListView()
                case .thoughts:
                    ThoughtRecordListView()
                case .sessions:
                    JournalSessionsListView()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}
