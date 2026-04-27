import Foundation

final class AffirmationsLoader {
    static let shared = AffirmationsLoader()
    
    let affirmations: [Affirmation]
    
    private init() {
        if let url = Bundle.main.url(forResource: "Affirmations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([Affirmation].self, from: data) {
            self.affirmations = loaded
        } else {
            self.affirmations = []
        }
    }
}
