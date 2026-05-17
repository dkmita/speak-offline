import SwiftUI

struct FlashcardView: View {
    @StateObject var viewModel: FlashcardViewModel
    @State private var isMicPressed = false
    @State private var showingAnalytics = false

    var body: some View {
        VStack(spacing: 24) {
            if let card = viewModel.currentCard {
                // Card metadata row: section/unit/CEFR, review history dots,
                // and a button to open the analytics sheet.
                HStack(spacing: 10) {
                    Text(cardMetadata(card))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            let dot = viewModel.recentResults[4 - i]
                            Circle()
                                .fill(dot == true ? Color.green
                                      : dot == false ? Color.red
                                      : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }

                    Spacer()

                    Button {
                        showingAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Open analytics")
                }
                .padding(.horizontal)
                .padding(.top, 4)

                Spacer()

                // Question card
                TappableWordsView(
                    text: card.back,
                    answerText: card.front,
                    font: .title3,
                    bold: true
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                // Show-answer / answer slot. The answer is always rendered so
                // the slot's size is fixed; the Show Answer button overlays it
                // until tapped. Tapping fades the button out and the answer in
                // without moving anything below.
                ZStack {
                    AnswerWordsView(
                        text: card.front,
                        phonetic: card.phonetic,
                        font: .body
                    )
                    .opacity(viewModel.isShowingAnswer ? 1 : 0)
                    .accessibilityHidden(!viewModel.isShowingAnswer)

                    if !viewModel.isShowingAnswer {
                        Button("Show Answer") {
                            withAnimation {
                                viewModel.showAnswer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.secondary)
                    }
                }
                .padding(.horizontal)

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
                    // Before answer is shown: skip without rating.
                    Button("Skip") {
                        viewModel.skip()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.secondary)
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
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isShowingAnswer)
        .animation(.easeInOut(duration: 0.25), value: viewModel.speechMatched)
        .sheet(isPresented: $showingAnalytics) {
            NavigationStack {
                PhraseListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingAnalytics = false }
                        }
                    }
            }
        }
    }

    // MARK: - Card Metadata

    /// Format: "Traveler 3.5 · A1"
    /// Maps the legacy (unit, section) fields back to Duolingo's
    /// section-name + within-section unit numbering.
    private func cardMetadata(_ card: Card) -> String {
        let sectionNames = ["Rookie", "Explorer", "Traveler", "Trailblazer",
                            "Pathfinder", "Wanderer", "Challenger", "Navigator"]
        // Cumulative unit count before each section (index = section number)
        let offsets = [0, 0, 8, 34, 62, 114, 164, 214, 250]
        let s = card.unit
        guard (1...8).contains(s) else { return card.cefrLevel }
        let unitWithinSection = card.section - offsets[s]
        return "\(sectionNames[s - 1]) \(s).\(unitWithinSection) · \(card.cefrLevel)"
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
            }
        }
    }

    /// Full-width press-and-hold mic button. Sized prominently and pinned to
    /// a fixed height so the button never shifts as answers/hints/transcripts
    /// change above or below it. Errors render inline as the button label so
    /// they don't push surrounding layout around.
    private var micButton: some View {
        let listening = viewModel.speechService.isListening
        let error = viewModel.speechService.error
        let hasError = error != nil && !listening
        let label: String = {
            if listening { return "Listening — speak now..." }
            if let error { return error }
            return "Hold to speak"
        }()
        return HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.title)
                .symbolEffect(.pulse, isActive: listening)
            Text(label)
                .font(hasError ? .subheadline : .title3)
                .bold()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .padding(.horizontal, 20)
        .foregroundStyle(foregroundStyleForMic(listening: listening, hasError: hasError))
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(backgroundFillForMic(listening: listening, hasError: hasError))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColorForMic(listening: listening, hasError: hasError), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
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

    private func foregroundStyleForMic(listening: Bool, hasError: Bool) -> Color {
        if listening { return .white }
        if hasError { return .red }
        return Color.accentColor
    }

    private func backgroundFillForMic(listening: Bool, hasError: Bool) -> Color {
        if listening { return .red }
        if hasError { return Color.red.opacity(0.10) }
        return Color.accentColor.opacity(0.12)
    }

    private func borderColorForMic(listening: Bool, hasError: Bool) -> Color {
        if listening { return Color.red.opacity(0.4) }
        if hasError { return Color.red.opacity(0.35) }
        return .clear
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
