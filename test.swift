import Foundation
import AppKit

let faces = ["hands.sparkles", "person.crop.circle.badge.exclamationmark", "aqi.low", "aqi.high"]
// wait, I can just grep the SF Symbols framework if I knew where it was.
// The easiest is just an array:
var possible = ["face", "frown", "smile", "sad", "happy", "cry", "tear"]
for p in possible {
    print("Testing \(p)...")
}
