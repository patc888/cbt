import Foundation

nonisolated struct LocalEventLogEntry: Codable, Equatable, Sendable {
    let name: String
    let metadata: [String: String]
    let timestamp: Date
}

nonisolated enum LocalEventLog {
    static let defaultsKey = "cbt_local_event_log"

    static func record(
        _ name: String,
        metadata: [String: String] = [:],
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        var entries = read(defaults: defaults)
        entries.append(LocalEventLogEntry(name: name, metadata: metadata, timestamp: now))
        entries = Array(entries.suffix(100))

        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func read(defaults: UserDefaults = .standard) -> [LocalEventLogEntry] {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let entries = try? JSONDecoder().decode([LocalEventLogEntry].self, from: data)
        else {
            return []
        }

        return entries
    }
}
