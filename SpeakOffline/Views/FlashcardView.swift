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
            micButton

            if !viewModel.speechService.transcript.isEmpty {
                HStack(spacing: 6) {
                    if let matched = viewModel.speechMatched {
                        Image(systemName: matched ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(matched ? .green : .yellow)
                    }
                    Text(viewModel.coloredTranscript())
                        .font(.body)
                        .italic()
                    playbackButton
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
            } else if viewModel.speechService.lastRecordingURL != nil
                && !viewModel.speechService.isListening {
                // Recorded audio but nothing recognized — let the user still
                // hear themselves.
                playbackButton
                    .transition(.opacity)
            } else if let error = viewModel.speechService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// Full-width press-and-hold mic button, styled to match the .bordered
    /// rating buttons below. Tint flips to red while recording.
    private var micButton: some View {
        let listening = viewModel.speechService.isListening
        return HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .symbolEffect(.pulse, isActive: listening)
            Text(listening ? "Listening — speak now..." : "Hold to speak")
                .font(.subheadline)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .foregroundStyle(listening ? Color.white : Color.accentColor)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(listening ? Color.red : Color.accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(listening ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
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
    }

    private var playbackButton: some View {
        Button {
            if viewModel.speechService.isPlayingBack {
                viewModel.speechService.stopPlayback()
            } else {
                viewModel.speechService.playLastRecording()
            }
        } label: {
            Image(systemName: viewModel.speechService.isPlayingBack ? "stop.circle.fill" : "play.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, isActive: viewModel.speechService.isPlayingBack)
        }
        .accessibilityLabel(viewModel.speechService.isPlayingBack ? "Stop playback" : "Play your recording")
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
