import Foundation
import SwiftData

enum LibraryItemType: String, Codable, CaseIterable, Identifiable {
    case audio = "Audio"
    case article = "Article"
    case exercise = "Exercise"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .audio:
            return "headphones"
        case .article:
            return "doc.text"
        case .exercise:
            return "figure.mind.and.body"
        }
    }
}

@Model
final class LibraryItem {
    var id: String = ""
    var title: String = ""
    var category: String = ""
    var contentData: Data = Data()
    var typeRawValue: String = LibraryItemType.exercise.rawValue
    var duration: Int = 0

    var type: LibraryItemType {
        get { LibraryItemType(rawValue: typeRawValue) ?? .exercise }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        category: String,
        contentData: Data = Data(),
        type: LibraryItemType,
        duration: Int
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.contentData = contentData
        self.typeRawValue = type.rawValue
        self.duration = duration
    }
}
