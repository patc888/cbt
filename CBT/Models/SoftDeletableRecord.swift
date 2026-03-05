import SwiftData

protocol SoftDeletableRecord: PersistentModel {
    var isDeleted: Bool { get set }
}
