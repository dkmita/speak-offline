import SwiftUI

@main
struct SpeakOfflineApp: App {
    @StateObject private var settings = UserSettings.shared

    var body: some Scene {
        WindowGroup {
            if settings.hasCompletedOnboarding {
                DeckListView()
                    .environmentObject(settings)
            } else {
                NavigationStack {
                    LevelPickerView(settings: settings, isOnboarding: true) {
                        // onDone — onboarding sets hasCompletedOnboarding = true
                    }
                }
            }
        }
    }
}
