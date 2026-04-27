import Foundation
import SwiftData

protocol SoftDeletableRecord: PersistentModel {
    var id: UUID { get set }
    var isDeleted: Bool { get set }
}
