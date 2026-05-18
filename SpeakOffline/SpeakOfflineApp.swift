import SwiftUI

@main
struct SpeakOfflineApp: App {
    @StateObject private var settings = UserSettings.shared

    init() {
        // Parse and load the bundled vocab JSON off the first user tap.
        // Without this, the first tap on the first card after launch takes a
        // ~50–100 ms one-time hit from the lazy singleton initializing.
        Task.detached(priority: .utility) {
            _ = VocabularyService.shared
        }
    }

    var body: some Scene {
        WindowGroup {
            FlashcardView(viewModel: FlashcardViewModel(
                deckName: "All cards",
                languageCode: "es",
                settings: settings
            ))
            .environmentObject(settings)
        }
    }
}
