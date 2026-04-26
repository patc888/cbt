import Foundation
import SwiftData

struct AppPreferencesStore {
    func fetchOrCreate(in modelContext: ModelContext) throws -> AppPreferences {
        let descriptor = FetchDescriptor<AppPreferences>(
            predicate: #Predicate<AppPreferences> { preferences in
                preferences.id == "app-preferences"
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let existingPreferences = try modelContext.fetch(descriptor)

        if let existing = existingPreferences.first {
            for duplicate in existingPreferences.dropFirst() {
                modelContext.delete(duplicate)
            }
            if existingPreferences.count > 1 {
                try modelContext.save()
            }
            return existing
        }

        let preferences = AppPreferences()
        modelContext.insert(preferences)
        try modelContext.save()
        return preferences
    }

    func save(_ preferences: AppPreferences, in modelContext: ModelContext) throws {
        preferences.updatedAt = .now
        try modelContext.save()
    }
}
