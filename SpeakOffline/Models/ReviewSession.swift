import Foundation
import GRDB

struct ReviewSession: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var cardId: Int64
    var quality: Int        // 0-5 rating
    var reviewedAt: Date

    static let card = belongsTo(Card.self)

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
