import SwiftUI

struct DeckListView: View {
    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        NavigationStack {
            List(CEFRLevel.allCases) { level in
                NavigationLink(value: level) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.rawValue)
                                .font(.headline)
                            Text(level.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(level.cardCountLabel)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if settings.currentLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("SpeakOffline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PhraseListView()
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
            }
            .navigationDestination(for: CEFRLevel.self) { level in
                FlashcardView(viewModel: FlashcardViewModel(
                    deckName: level.rawValue,
                    languageCode: "es",
                    settings: settings
                ))
                .onAppear {
                    settings.maxSection = level.maxSection
                }
            }
        }
    }
}
