import Foundation
import Combine

final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let maxSection = "maxSection"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    @Published var maxSection: Int {
        didSet { defaults.set(maxSection, forKey: Keys.maxSection) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var currentLevel: CEFRLevel {
        CEFRLevel.from(section: maxSection)
    }

    private init() {
        let saved = defaults.integer(forKey: Keys.maxSection)
        self.maxSection = saved > 0 ? saved : 8  // default to Intro
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}

enum CEFRLevel: String, CaseIterable, Identifiable {
    case intro = "Intro"
    case a1 = "A1 - Beginner"
    case a2 = "A2 - Elementary"
    case b1 = "B1 - Intermediate"
    case b2 = "B2 - Upper Intermediate"

    var id: String { rawValue }

    var maxSection: Int {
        switch self {
        case .intro: return 8
        case .a1: return 62
        case .a2: return 114
        case .b1: return 214
        case .b2: return 286
        }
    }

    var description: String {
        switch self {
        case .intro: return "Basic sentences, greetings, getting around"
        case .a1: return "Everyday conversations, present tense, basic past"
        case .a2: return "Past tenses, future, conditionals"
        case .b1: return "Subjunctive, perfect tenses, complex grammar"
        case .b2: return "Advanced grammar, nuanced conversations"
        }
    }

    var cardCountLabel: String {
        switch self {
        case .intro: return "24 cards"
        case .a1: return "186 cards"
        case .a2: return "341 cards"
        case .b1: return "635 cards"
        case .b2: return "851 cards"
        }
    }

    static func from(section: Int) -> CEFRLevel {
        switch section {
        case ...8: return .intro
        case ...62: return .a1
        case ...114: return .a2
        case ...214: return .b1
        default: return .b2
        }
    }
}
