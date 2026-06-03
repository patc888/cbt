import Foundation
import SwiftData

@Model
final class RetentionEvent {
    @Attribute(.unique) var id: UUID
    var eventName: String
    var timestamp: Date
    var metadataStorage: String
    var sourceScreen: String?
    var appVersion: String?
    var sessionID: String?

    init(
        id: UUID = UUID(),
        eventName: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        sourceScreen: String? = nil,
        appVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
        sessionID: String? = RetentionEventSession.currentID
    ) {
        self.id = id
        self.eventName = eventName
        self.timestamp = timestamp
        self.metadataStorage = Self.encodeMetadata(metadata)
        self.sourceScreen = sourceScreen
        self.appVersion = appVersion
        self.sessionID = sessionID
    }

    var metadata: [String: String] {
        get { Self.decodeMetadata(metadataStorage) }
        set { metadataStorage = Self.encodeMetadata(newValue) }
    }

    static func encodeMetadata(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty,
              let data = try? JSONEncoder().encode(metadata),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func decodeMetadata(_ storage: String) -> [String: String] {
        guard let data = storage.data(using: .utf8),
              let metadata = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return metadata
    }
}

enum RetentionEventSession {
    static let currentID = UUID().uuidString
}
