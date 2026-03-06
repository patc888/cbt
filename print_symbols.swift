import Foundation
import AppKit

if #available(macOS 11.0, *) {
    let faces = ["face.smiling", "face.smiling.fill", "face.frowning", "face.frowning.fill", "face.dashed", "face.smiling.inverse", "face.dashed.fill", "star.fill"]
    for face in faces {
        if NSImage(systemSymbolName: face, accessibilityDescription: nil) != nil {
            print("\(face): YES")
        } else {
            print("\(face): NO")
        }
    }
} else {
    print("Not available")
}
