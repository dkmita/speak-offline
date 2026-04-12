import Foundation
import GRDB

struct Card: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var deckId: Int64
    var front: String       // word/phrase in target language (Spanish)
    var back: String        // translation (English)
    var phonetic: String?   // pronunciation hint

    // Spaced repetition fields (SM-2 algorithm)
    var interval: Int       // days until next review
    var repetitions: Int    // consecutive correct answers
    var easeFactor: Double  // difficulty multiplier (≥ 1.3)
    var nextReviewDate: Date

    static let deck = belongsTo(Deck.self)

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    /// Update spaced repetition fields based on a quality rating (0-5).
    /// 0-2 = forgot, 3 = hard, 4 = good, 5 = easy
    mutating func applyReview(quality: Int) {
        let q = Double(min(max(quality, 0), 5))

        if q < 3 {
            // Reset on failure
            repetitions = 0
            interval = 1
        } else {
            switch repetitions {
            case 0: interval = 1
            case 1: interval = 6
            default: interval = Int(round(Double(interval) * easeFactor))
            }
            repetitions += 1
        }

        // Update ease factor (SM-2 formula)
        easeFactor = max(1.3, easeFactor + 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02))
        nextReviewDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
    }
}

extension Card {
    /// Create a new card with default spaced repetition values
    static func new(deckId: Int64, front: String, back: String, phonetic: String? = nil) -> Card {
        Card(
            deckId: deckId,
            front: front,
            back: back,
            phonetic: phonetic,
            interval: 0,
            repetitions: 0,
            easeFactor: 2.5,
            nextReviewDate: Date()
        )
    }
}
