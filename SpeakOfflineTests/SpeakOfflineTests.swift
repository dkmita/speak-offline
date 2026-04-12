import XCTest
@testable import SpeakOffline

final class CardReviewTests: XCTestCase {
    func testSM2_correctAnswerIncreasesInterval() {
        var card = Card.new(deckId: 1, front: "Hola", back: "Hello")

        card.applyReview(quality: 4) // Good
        XCTAssertEqual(card.repetitions, 1)
        XCTAssertEqual(card.interval, 1)

        card.applyReview(quality: 4) // Good again
        XCTAssertEqual(card.repetitions, 2)
        XCTAssertEqual(card.interval, 6)

        card.applyReview(quality: 4) // Good again
        XCTAssertEqual(card.repetitions, 3)
        XCTAssertGreaterThan(card.interval, 6)
    }

    func testSM2_failedAnswerResetsRepetitions() {
        var card = Card.new(deckId: 1, front: "Hola", back: "Hello")
        card.applyReview(quality: 4)
        card.applyReview(quality: 4)

        card.applyReview(quality: 1) // Failed
        XCTAssertEqual(card.repetitions, 0)
        XCTAssertEqual(card.interval, 1)
    }

    func testSM2_easeFactorNeverBelowMinimum() {
        var card = Card.new(deckId: 1, front: "Hola", back: "Hello")

        // Repeated hard ratings should not drop ease below 1.3
        for _ in 0..<20 {
            card.applyReview(quality: 3)
        }
        XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3)
    }
}
