import Foundation

enum StringArrayStorage {
    private static let fallbackStorage = "[]"

    static func encode(_ values: [String]) -> String {
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard
            let data = try? JSONEncoder().encode(normalized),
            let json = String(data: data, encoding: .utf8)
        else {
            return fallbackStorage
        }

        return json
    }

    static func decode(_ value: String) -> [String] {
        guard let data = value.data(using: .utf8) else {
            return []
        }

        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
