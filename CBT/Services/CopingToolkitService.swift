import Foundation

nonisolated enum CopingToolkitFilter: String, CaseIterable, Codable, Identifiable {
    case anxiety = "anxiety"
    case panic = "panic"
    case sadness = "low mood"
    case anger = "anger"
    case overwhelm = "overwhelm"
    case sleep = "sleep"
    case stress = "stress"
    case quickReset = "quick reset"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anxiety: return "Anxiety"
        case .panic: return "Panic"
        case .sadness: return "Sadness"
        case .anger: return "Anger"
        case .overwhelm: return "Overwhelm"
        case .sleep: return "Sleep"
        case .stress: return "Stress"
        case .quickReset: return "Quick reset"
        }
    }
}

nonisolated enum CopingToolkitDestination: Hashable {
    case exercise(String)
    case breathing(Int)
    case safety
}

nonisolated struct CopingToolkitTool: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let kind: String
    let durationMinutes: Int
    let systemImage: String
    let categories: [CopingToolkitFilter]
    let destination: CopingToolkitDestination

    var durationLabel: String {
        durationMinutes <= 1 ? "1 min" : "\(durationMinutes) min"
    }
}

nonisolated struct CopingToolkitUsage: Codable, Equatable {
    let toolID: String
    let usedAt: Date
}

nonisolated struct CopingToolkitStore {
    private let defaults: UserDefaults
    private let favoritesKey: String
    private let usageKey: String
    private let copingPlanKey: String
    private let usageLimit = 30
    let maximumCopingPlanTools = 5

    init(
        defaults: UserDefaults = .standard,
        favoritesKey: String = "cbt_coping_toolkit_favorite_ids",
        usageKey: String = "cbt_coping_toolkit_usage",
        copingPlanKey: String = "cbt_coping_toolkit_coping_plan_ids"
    ) {
        self.defaults = defaults
        self.favoritesKey = favoritesKey
        self.usageKey = usageKey
        self.copingPlanKey = copingPlanKey
    }

    var favoriteIDs: [String] {
        defaults.stringArray(forKey: favoritesKey) ?? []
    }

    func isFavorite(_ toolID: String) -> Bool {
        favoriteIDs.contains(toolID)
    }

    @discardableResult
    func toggleFavorite(_ toolID: String) -> Bool {
        var ids = favoriteIDs
        if let index = ids.firstIndex(of: toolID) {
            ids.remove(at: index)
            defaults.set(ids, forKey: favoritesKey)
            return false
        } else {
            ids.insert(toolID, at: 0)
            defaults.set(ids, forKey: favoritesKey)
            return true
        }
    }

    var usage: [CopingToolkitUsage] {
        guard let data = defaults.data(forKey: usageKey),
              let decoded = try? JSONDecoder().decode([CopingToolkitUsage].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.usedAt > $1.usedAt }
    }

    func recordUsage(_ toolID: String, at date: Date = Date()) {
        var events = usage.filter { $0.toolID != toolID }
        events.insert(CopingToolkitUsage(toolID: toolID, usedAt: date), at: 0)
        events = Array(events.prefix(usageLimit))
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: usageKey)
        }
    }

    func recentToolIDs(limit: Int = 5) -> [String] {
        Array(usage.map(\.toolID).prefix(limit))
    }

    var copingPlanToolIDs: [String] {
        defaults.stringArray(forKey: copingPlanKey) ?? []
    }

    func isInCopingPlan(_ toolID: String) -> Bool {
        copingPlanToolIDs.contains(toolID)
    }

    @discardableResult
    func toggleCopingPlanTool(_ toolID: String) -> Bool {
        var ids = copingPlanToolIDs
        if let index = ids.firstIndex(of: toolID) {
            ids.remove(at: index)
            defaults.set(ids, forKey: copingPlanKey)
            return false
        } else {
            guard ids.count < maximumCopingPlanTools else { return false }
            ids.insert(toolID, at: 0)
            defaults.set(ids, forKey: copingPlanKey)
            return true
        }
    }

    func canAddCopingPlanTool(_ toolID: String) -> Bool {
        isInCopingPlan(toolID) || copingPlanToolIDs.count < maximumCopingPlanTools
    }
}

@MainActor
final class CopingToolkitService {
    static let shared = CopingToolkitService(exerciseService: .shared)

    private let exerciseService: ExerciseService

    init(exerciseService: ExerciseService) {
        self.exerciseService = exerciseService
    }

    var tools: [CopingToolkitTool] {
        let breathingShortcuts = [
            CopingToolkitTool(
                id: "toolkit_breathing_60",
                title: "Breathing Reset",
                subtitle: "One minute of paced breathing.",
                kind: "Breathing tool",
                durationMinutes: 1,
                systemImage: "wind",
                categories: [.anxiety, .panic, .overwhelm, .stress, .quickReset],
                destination: .breathing(60)
            ),
            CopingToolkitTool(
                id: "toolkit_breathing_120",
                title: "Longer Breathing Reset",
                subtitle: "Two minutes to settle the nervous system.",
                kind: "Breathing tool",
                durationMinutes: 2,
                systemImage: "lungs.fill",
                categories: [.anxiety, .panic, .overwhelm, .sleep, .stress, .quickReset],
                destination: .breathing(120)
            )
        ]

        let exerciseTools = exerciseService.exercises
            .filter(\.isToolkitTool)
            .map(Self.makeTool(from:))

        return (breathingShortcuts + exerciseTools).sorted {
            if $0.durationMinutes == $1.durationMinutes {
                return $0.title < $1.title
            }
            return $0.durationMinutes < $1.durationMinutes
        }
    }

    func filteredTools(for filter: CopingToolkitFilter?) -> [CopingToolkitTool] {
        guard let filter else { return tools }
        return tools.filter { $0.categories.contains(filter) }
    }

    func favorites(using store: CopingToolkitStore = CopingToolkitStore(), limit: Int? = nil) -> [CopingToolkitTool] {
        let toolsByID = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0) })
        let values = store.favoriteIDs.compactMap { toolsByID[$0] }
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }

    func recentlyUsed(using store: CopingToolkitStore = CopingToolkitStore(), limit: Int = 5) -> [CopingToolkitTool] {
        let toolsByID = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0) })
        return store.recentToolIDs(limit: limit).compactMap { toolsByID[$0] }
    }

    func copingPlanTools(using store: CopingToolkitStore = CopingToolkitStore(), limit: Int? = nil) -> [CopingToolkitTool] {
        let toolsByID = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0) })
        let values = store.copingPlanToolIDs.compactMap { toolsByID[$0] }
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }

    private static func makeTool(from exercise: Exercise) -> CopingToolkitTool {
        CopingToolkitTool(
            id: exercise.id,
            title: exercise.title,
            subtitle: exercise.description,
            kind: exercise.toolkitKind,
            durationMinutes: max(exercise.duration, 1),
            systemImage: icon(for: exercise),
            categories: exercise.toolkitCategories,
            destination: .exercise(exercise.id)
        )
    }

    private static func icon(for exercise: Exercise) -> String {
        let text = "\(exercise.title) \(exercise.toolkitKind) \((exercise.tags ?? []).joined(separator: " "))".lowercased()
        if text.contains("breath") { return "wind" }
        if text.contains("ground") || text.contains("senses") { return "hand.raised.fill" }
        if text.contains("defusion") || text.contains("thought") { return "brain.head.profile" }
        if text.contains("compassion") { return "heart.fill" }
        if text.contains("worry") { return "calendar.badge.clock" }
        if text.contains("urge") { return "waveform.path.ecg" }
        if text.contains("scan") || text.contains("body") { return "figure.mind.and.body" }
        if text.contains("value") { return "sparkle.magnifyingglass" }
        return "lifepreserver"
    }
}
