import Foundation
import GRDB

struct Deck: Codable, Identifiable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var description: String
    var languageCode: String  // e.g. "es"
    var createdAt: Date

    static let cards = hasMany(Card.self)
    var cards: QueryInterfaceRequest<Card> {
        request(for: Deck.cards)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
