import SwiftUI

struct FlashcardView: View {
    @StateObject var viewModel: FlashcardViewModel
    @State private var isMicPressed = false

    var body: some View {
        VStack(spacing: 24) {
            if let card = viewModel.currentCard {
                Spacer()

                // Question card
                VStack(spacing: 16) {
                    TappableWordsView(
                        text: card.back,
                        answerText: card.front,
                        font: .title3,
                        bold: true
                    )
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Answer block — always rendered so the layout doesn't shift
                // when the answer is revealed; visibility toggled via opacity.
                VStack(spacing: 4) {
                    Text(card.front)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if let phonetic = card.phonetic {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal)
                .opacity(viewModel.isShowingAnswer ? 1 : 0)
                .accessibilityHidden(!viewModel.isShowingAnswer)

                Spacer()

                // Show Answer
                if !viewModel.isShowingAnswer {
                    Button("Show Answer") {
                        withAnimation {
                            viewModel.showAnswer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                } else {
                    // Invisible placeholder to keep layout stable
                    Button("Show Answer") {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .hidden()
                }

                // Mic + transcript
                micSection

                // Rating buttons — always take up space
                if viewModel.isShowingAnswer {
                    if viewModel.speechMatched == true {
                        Button("Next") {
                            viewModel.rate(quality: 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        manualRatingButtons
                    }
                } else {
                    manualRatingButtons
                        .hidden()
                }

                // Progress
                Text("\(viewModel.cardsReviewed) reviewed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)

            } else {
                ContentUnavailableView(
                    "No cards available",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Try selecting a different level.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(viewModel.deckName)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isShowingAnswer)
        .animation(.easeInOut(duration: 0.25), value: viewModel.speechMatched)
    }

    // MARK: - Mic Section

    private var micSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.title)
                .symbolEffect(.pulse, isActive: viewModel.speechService.isListening)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(viewModel.speechService.isListening ? Color.red : Color.accentColor)
                )
                .overlay(
                    Circle()
                        .stroke(viewModel.speechService.isListening ? Color.red.opacity(0.4) : Color.clear, lineWidth: 3)
                        .scaleEffect(viewModel.speechService.isListening ? 1.4 : 1.0)
                        .opacity(viewModel.speechService.isListening ? 0 : 1)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: viewModel.speechService.isListening)
                )
                .shadow(color: viewModel.speechService.isListening ? .red.opacity(0.4) : .accentColor.opacity(0.3), radius: 8)
                .contentShape(Circle())
                // DragGesture(minimumDistance: 0) fires onChanged on the initial
                // touch-down and onEnded on touch-up — i.e. press-and-hold.
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isMicPressed else { return }
                            isMicPressed = true
                            Task { await viewModel.startPushToTalk() }
                        }
                        .onEnded { _ in
                            isMicPressed = false
                            viewModel.endPushToTalk()
                        }
                )
                .accessibilityLabel("Hold to record")
                .accessibilityAddTraits(.isButton)

            if !viewModel.speechService.transcript.isEmpty {
                HStack(spacing: 6) {
                    if let matched = viewModel.speechMatched {
                        Image(systemName: matched ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(matched ? .green : .yellow)
                    }
                    Text(viewModel.coloredTranscript())
                        .font(.body)
                        .italic()
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .transition(.opacity)

                if viewModel.speechMatched == false {
                    Text("Not quite — try again or show answer")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            } else if viewModel.speechService.isListening {
                Text("Listening — speak now...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let error = viewModel.speechService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Hold mic to speak")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Rating Buttons

    private var manualRatingButtons: some View {
        HStack(spacing: 12) {
            // Got it — secondary, subtle green
            Button {
                viewModel.rate(quality: 4)
            } label: {
                Text("Got it")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.green.opacity(0.6))

            // Didn't get it — primary, subtle red
            Button {
                viewModel.rate(quality: 1)
            } label: {
                Text("Next")
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}
