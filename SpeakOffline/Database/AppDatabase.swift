import Foundation
import GRDB

final class AppDatabase {
    let dbQueue: DatabaseQueue

    init(_ dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            try db.create(table: "deck") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("description", .text).notNull().defaults(to: "")
                t.column("languageCode", .text).notNull().defaults(to: "es")
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "card") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("deck", onDelete: .cascade).notNull()
                t.column("front", .text).notNull()
                t.column("back", .text).notNull()
                t.column("phonetic", .text)
                t.column("unit", .integer).notNull().defaults(to: 1)
                t.column("section", .integer).notNull().defaults(to: 1)
                t.column("cefrLevel", .text).notNull().defaults(to: "Intro")
                t.column("interval", .integer).notNull().defaults(to: 0)
                t.column("repetitions", .integer).notNull().defaults(to: 0)
                t.column("easeFactor", .double).notNull().defaults(to: 2.5)
                t.column("nextReviewDate", .datetime).notNull()
            }

            try db.create(table: "reviewSession") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("card", onDelete: .cascade).notNull()
                t.column("quality", .integer).notNull()
                t.column("reviewedAt", .datetime).notNull()
            }

            try db.create(index: "card_on_section", on: "card", columns: ["section"])
        }

        try migrator.migrate(dbQueue)
    }

    /// Seed the database from bundled JSON if no decks exist
    func seedIfEmpty() throws {
        try dbQueue.write { db in
            let count = try Deck.fetchCount(db)
            guard count == 0 else {
                print("[SpeakOffline] Database already has \(count) decks, skipping seed")
                return
            }

            let url = Bundle.main.url(forResource: "seed", withExtension: "json")
            guard let url else {
                print("[SpeakOffline] seed.json not found in bundle")
                return
            }
            guard let data = try? Data(contentsOf: url) else {
                print("[SpeakOffline] Failed to read seed.json at \(url)")
                return
            }
            print("[SpeakOffline] Loading seed data from \(url)")

            let seedData = try JSONDecoder.appDecoder.decode(SeedData.self, from: data)

            for seedDeck in seedData.decks {
                var deck = Deck(
                    name: seedDeck.name,
                    description: seedDeck.description,
                    languageCode: seedDeck.languageCode,
                    createdAt: Date()
                )
                try deck.insert(db)

                for seedCard in seedDeck.cards {
                    var card = Card.new(
                        deckId: deck.id!,
                        front: seedCard.front,
                        back: seedCard.back,
                        phonetic: seedCard.phonetic,
                        unit: seedCard.unit,
                        section: seedCard.section,
                        cefrLevel: seedCard.cefrLevel
                    )
                    try card.insert(db)
                }
            }
            print("[SpeakOffline] Seeded \(try Card.fetchCount(db)) cards")
        }
    }
}

// MARK: - Seed data JSON model

private struct SeedData: Codable {
    struct SeedDeck: Codable {
        let name: String
        let description: String
        let languageCode: String
        let cards: [SeedCard]
    }
    struct SeedCard: Codable {
        let front: String
        let back: String
        let phonetic: String?
        let unit: Int
        let section: Int
        let cefrLevel: String
    }
    let decks: [SeedDeck]
}

// MARK: - Shared database instance

extension AppDatabase {
    static let shared = makeShared()

    private static func makeShared() -> AppDatabase {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = appSupportURL.appendingPathComponent("speakoffline.sqlite")
            let dbQueue = try DatabaseQueue(path: dbURL.path)
            let database = try AppDatabase(dbQueue)
            try database.seedIfEmpty()
            return database
        } catch {
            fatalError("Database setup failed: \(error)")
        }
    }
}

// MARK: - JSON decoder

extension JSONDecoder {
    static let appDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
