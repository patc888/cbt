import Foundation
import SwiftData

@available(macOS 14.0, iOS 17.0, *)
func printStorePath() {
    let container = try? ModelContainer(for: Schema([]))
    // we can't easily get the URL from container directly in a script, but the default URL is:
    // ModelConfiguration().url
    let configURL = ModelConfiguration().url
    print("Default SwiftData url: \(configURL.path)")
}
printStorePath()
