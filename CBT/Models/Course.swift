import Foundation
import SwiftData

@Model
final class Course {
    var id: String = ""
    var title: String = ""
    var itemIDsStorage: String = "[]"
    var completedItemIDsStorage: String = "[]"
    var isCompleted: Bool = false

    var itemIDs: [String] {
        get { StringArrayStorage.decode(itemIDsStorage) }
        set {
            itemIDsStorage = StringArrayStorage.encode(newValue)
            updateCompletionState()
        }
    }

    var completedItemIDs: [String] {
        get { StringArrayStorage.decode(completedItemIDsStorage) }
        set {
            completedItemIDsStorage = StringArrayStorage.encode(newValue)
            updateCompletionState()
        }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        itemIDs: [String],
        completedItemIDs: [String] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.itemIDsStorage = StringArrayStorage.encode(itemIDs)
        self.completedItemIDsStorage = StringArrayStorage.encode(completedItemIDs)
        self.isCompleted = isCompleted
        updateCompletionState()
    }

    func markCompleted(itemID: String) {
        guard itemIDs.contains(itemID) else { return }
        var updated = completedItemIDs
        if !updated.contains(itemID) {
            updated.append(itemID)
        }
        completedItemIDs = updated
    }

    func orderedItems(from libraryItems: [LibraryItem]) -> [LibraryItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: libraryItems.map { ($0.id, $0) })
        return itemIDs.compactMap { itemsByID[$0] }
    }

    func progressIndex(in libraryItems: [LibraryItem]) -> Int {
        let orderedIDs = orderedItems(from: libraryItems).map(\.id)
        return orderedIDs.firstIndex { !completedItemIDs.contains($0) } ?? max(orderedIDs.count - 1, 0)
    }

    private func updateCompletionState() {
        let ids = itemIDs
        isCompleted = !ids.isEmpty && ids.allSatisfy { completedItemIDs.contains($0) }
    }
}
