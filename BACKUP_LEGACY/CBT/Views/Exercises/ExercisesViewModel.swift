import Foundation
import SwiftData
import SwiftUI
import Observation

@Observable
final class ExercisesViewModel {
    var isInitialized = false
    var completionIDs = Set<String>()
    var recentCompletionIDs = [String]()
    var upNextExercises = [Exercise]()
    var recentlyCompletedExercises = [Exercise]()
    
    private var updateTaskID = UUID()
    
    @MainActor
    func update(completions: [ExerciseCompletion], allExercises: [Exercise]) async {
        let currentTaskID = UUID()
        self.updateTaskID = currentTaskID
        
        // Snapshot completion details on the MainActor before detached work
        let completionIDsSnapshot = completions.map(\.exerciseID)
        
        let results = await Task.detached(priority: .userInitiated) {
            let ids = Set(completionIDsSnapshot)
            
            // Recent unique completions
            var uniqueRecentIDs: [String] = []
            for id in completionIDsSnapshot {
                if uniqueRecentIDs.contains(id) { continue }
                uniqueRecentIDs.append(id)
                if uniqueRecentIDs.count == 3 { break }
            }
            
            let incomplete = allExercises.filter { !ids.contains($0.id) }
            let upNext = Array(incomplete.prefix(3))
            
            let recentlyCompleted = uniqueRecentIDs.compactMap { id in
                allExercises.first(where: { $0.id == id })
            }
            
            return (ids, uniqueRecentIDs, upNext, recentlyCompleted)
        }.value
        
        guard !Task.isCancelled, self.updateTaskID == currentTaskID else { return }
        
        self.completionIDs = results.0
        self.recentCompletionIDs = results.1
        self.upNextExercises = results.2
        self.recentlyCompletedExercises = results.3
        self.isInitialized = true
    }
}
