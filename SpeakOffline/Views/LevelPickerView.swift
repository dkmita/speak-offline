import SwiftUI

struct LevelPickerView: View {
    @ObservedObject var settings: UserSettings
    var isOnboarding: Bool = false
    var onDone: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            if isOnboarding {
                Text("What's your level?")
                    .font(.title2)
                    .bold()
                    .padding(.top, 32)

                Text("Choose where you are in your Spanish learning. You'll practice all phrases up to this level.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            List(CEFRLevel.allCases) { level in
                Button {
                    settings.maxSection = level.maxSection
                    if isOnboarding {
                        settings.hasCompletedOnboarding = true
                    }
                    onDone?()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.rawValue)
                                .font(.headline)
                                .foregroundStyle(.primary)
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
            .listStyle(.insetGrouped)
        }
        .navigationTitle(isOnboarding ? "" : "Choose Level")
        .navigationBarTitleDisplayMode(.inline)
    }
}
