import SwiftUI
import Observation

@Observable
final class AffirmationFavoritesStore {
    static let shared = AffirmationFavoritesStore()
    
    private let defaults = UserDefaults.standard
    private let favoritesKey = "affirmation_favorites_v1"
    
    var favoriteIDs: Set<String> {
        didSet {
            let array = Array(favoriteIDs)
            defaults.set(array, forKey: favoritesKey)
        }
    }
    
    private init() {
        if let saved = defaults.array(forKey: "affirmation_favorites_v1") as? [String] {
            self.favoriteIDs = Set(saved)
        } else {
            self.favoriteIDs = []
        }
    }
    
    func toggleFavorite(id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
    }
    
    func isFavorite(id: String) -> Bool {
        favoriteIDs.contains(id)
    }
}
