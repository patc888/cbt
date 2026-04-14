import Foundation

let fileManager = FileManager.default
if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
    let defaultStoreURL = appSupport.appendingPathComponent("default.store")
    let fallbackStoreURL = defaultStoreURL.deletingLastPathComponent().appendingPathComponent("local-recovery.store")
    
    print("Robust Default Store URL: \(defaultStoreURL.path)")
    print("Robust Fallback Store URL: \(fallbackStoreURL.path)")
} else {
    print("Failed to find Application Support directory")
}
