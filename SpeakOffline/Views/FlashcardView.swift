import SwiftUI

struct FlashcardView: View {
    @StateObject var viewModel: FlashcardViewModel

    var body: some View {
        VStack(spacing: 24) {
            if let card = viewModel.currentCard {
                Spacer()

                // Card
                VStack(spacing: 16) {
                    Text(card.front)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)

                    if let phonetic = card.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isShowingAnswer {
                        Divider()
                            .padding(.horizontal, 40)

                        Text(card.back)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)

                        // Mic button + transcript
                        micSection
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                // Controls
                if viewModel.isShowingAnswer {
                    ratingButtons
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button("Show Answer") {
                        withAnimation {
                            viewModel.showAnswer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                // Progress
                Text(viewModel.progress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)

            } else {
                ContentUnavailableView(
                    "All caught up!",
                    systemImage: "checkmark.circle",
                    description: Text("No cards due for review right now.")
                )
            }
        }
        .navigationTitle(viewModel.deckName)
        .animation(.default, value: viewModel.isShowingAnswer)
    }

    // MARK: - Mic Section

    private var micSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleMic() }
            } label: {
                Image(systemName: viewModel.speechService.isListening ? "mic.fill" : "mic")
                    .font(.title)
                    .foregroundStyle(viewModel.speechService.isListening ? .red : .accentColor)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(viewModel.speechService.isListening ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.1))
                    )
            }
            .accessibilityLabel(viewModel.speechService.isListening ? "Stop recording" : "Start recording")

            if !viewModel.speechService.transcript.isEmpty {
                Text(viewModel.speechService.transcript)
                    .font(.body)
                    .italic()
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            if viewModel.speechService.isListening {
                Text("Listening...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.speechService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            RatingButton(label: "Again", color: .red) {
                viewModel.rate(quality: 1)
            }
            RatingButton(label: "Hard", color: .orange) {
                viewModel.rate(quality: 3)
            }
            RatingButton(label: "Good", color: .green) {
                viewModel.rate(quality: 4)
            }
            RatingButton(label: "Easy", color: .blue) {
                viewModel.rate(quality: 5)
            }
        }
        .padding(.horizontal)
    }
}

private struct RatingButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
}
