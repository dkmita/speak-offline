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

        // One-shot purge of the legacy 851-card decks (Intro / A1 - Beginner /
        // A2 - Elementary / B1 - Intermediate / B2 - Upper Intermediate). The
        // current cards.json uses the Duolingo section names (Rookie /
        // Explorer / Traveler / ...), so any existing deck with a legacy name
        // is dead weight. Cascade deletes their cards and review sessions.
        // After this migration runs once, loadBundledCardsIfEmpty() repopulates
        // from cards.json if the DB ends up empty.
        migrator.registerMigration("v2_remove_legacy_decks") { db in
            try db.execute(sql: """
                DELETE FROM deck WHERE name IN
                ('Intro', 'A1 - Beginner', 'A2 - Elementary',
                 'B1 - Intermediate', 'B2 - Upper Intermediate')
            """)
        }

        try migrator.migrate(dbQueue)
    }

    /// Load the bundled cards.json into the database if no decks exist.
    /// Runs on every launch; no-ops once the DB has been populated.
    func loadBundledCardsIfEmpty() throws {
        try dbQueue.write { db in
            let count = try Deck.fetchCount(db)
            guard count == 0 else {
                print("[SpeakOffline] Database already has \(count) decks, skipping load")
                return
            }

            let url = Bundle.main.url(forResource: "cards", withExtension: "json")
            guard let url else {
                print("[SpeakOffline] cards.json not found in bundle")
                return
            }
            guard let data = try? Data(contentsOf: url) else {
                print("[SpeakOffline] Failed to read cards.json at \(url)")
                return
            }
            print("[SpeakOffline] Loading cards from \(url)")

            let library = try JSONDecoder.appDecoder.decode(CardLibrary.self, from: data)

            for libraryDeck in library.decks {
                var deck = Deck(
                    name: libraryDeck.name,
                    description: libraryDeck.description,
                    languageCode: libraryDeck.languageCode,
                    createdAt: Date()
                )
                try deck.insert(db)

                for entry in libraryDeck.cards {
                    var card = Card.new(
                        deckId: deck.id!,
                        front: entry.front,
                        back: entry.back,
                        phonetic: entry.phonetic,
                        unit: entry.unit,
                        section: entry.section,
                        cefrLevel: entry.cefrLevel
                    )
                    try card.insert(db)
                }
            }
            print("[SpeakOffline] Loaded \(try Card.fetchCount(db)) cards")
        }
    }
}

// MARK: - cards.json JSON model

private struct CardLibrary: Codable {
    struct LibraryDeck: Codable {
        let name: String
        let description: String
        let languageCode: String
        let cards: [LibraryCard]
    }
    struct LibraryCard: Codable {
        let front: String
        let back: String
        let phonetic: String?
        let unit: Int
        let section: Int
        let cefrLevel: String
    }
    let decks: [LibraryDeck]
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
            try database.loadBundledCardsIfEmpty()
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
