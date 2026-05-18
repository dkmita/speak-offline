import SwiftUI

struct FlashcardView: View {
    @StateObject var viewModel: FlashcardViewModel
    @EnvironmentObject private var settings: UserSettings
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
                            // The rightmost slot (i == 4) holds the newest
                            // review — when justAddedDotPending is true we
                            // scale it up briefly to draw attention.
                            let isNewest = (i == 4) && viewModel.justAddedDotPending
                            Circle()
                                .fill(dot == true ? Color.green
                                      : dot == false ? Color.red
                                      : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .scaleEffect(isNewest ? 2.6 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.55),
                                           value: viewModel.justAddedDotPending)
                        }
                    }

                    Spacer()

                    maxLevelMenu

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

                // Transcript / playback / "not quite" warning — placed above
                // the answer slot. minHeight keeps the area present even
                // before recording so the answer slot below doesn't shift
                // once speech recognition fills it in.
                transcriptSection

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

                // Press-and-hold mic — sits right above the rating/skip row.
                micButton

                // Action row — height is locked to the tallest variant
                // (manualRatingButtons) so the layout doesn't shift between
                // Skip / single Next / two-button rating.
                actionRow
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.isAdvancing)

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
                PhraseListView { cardId in
                    showingAnalytics = false
                    viewModel.loadCard(id: cardId)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingAnalytics = false }
                    }
                }
            }
        }
    }

    // MARK: - Course Structure

    /// Mirrors the section layout used to build seed.json. Index 0 = Rookie.
    private static let sectionNames = ["Rookie", "Explorer", "Traveler", "Trailblazer",
                                       "Pathfinder", "Wanderer", "Challenger", "Navigator"]
    private static let sectionCefr = ["Intro", "A1", "A1", "A2", "B1", "B1", "B2", "B2"]
    /// Cumulative unit counts. `sectionStartOffsets[i]` = total units before section i+1.
    /// So Rookie covers sections 1...8, Explorer 9...34, etc.
    private static let sectionStartOffsets = [0, 8, 34, 62, 114, 164, 214, 250]
    private static let sectionEndOffsets = [8, 34, 62, 114, 164, 214, 250, 286]

    /// Format: "Traveler 3.5 · A1"
    /// Maps the legacy (unit, section) fields back to Duolingo's
    /// section-name + within-section unit numbering.
    private func cardMetadata(_ card: Card) -> String {
        let s = card.unit
        guard (1...8).contains(s) else { return card.cefrLevel }
        let unitWithinSection = card.section - Self.sectionStartOffsets[s - 1]
        return "\(Self.sectionNames[s - 1]) \(s).\(unitWithinSection) · \(card.cefrLevel)"
    }

    // MARK: - Max Level Menu

    /// Menu that lets the user cap the pool of cards by section.
    /// Label shows the currently-selected level (e.g. "Up to A1").
    private var maxLevelMenu: some View {
        Menu {
            ForEach(0..<8) { i in
                Button {
                    settings.maxSection = Self.sectionEndOffsets[i]
                } label: {
                    let name = Self.sectionNames[i]
                    let cefr = Self.sectionCefr[i]
                    if settings.maxSection == Self.sectionEndOffsets[i] {
                        Label("\(cefr) · \(name)", systemImage: "checkmark")
                    } else {
                        Text("\(cefr) · \(name)")
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(currentMaxLevelLabel)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Maximum level")
    }

    /// "Up to A1", "Up to B1", or "Up to B2" depending on what maxSection covers.
    private var currentMaxLevelLabel: String {
        let max = settings.maxSection
        for i in 0..<8 {
            if max <= Self.sectionEndOffsets[i] {
                return "Up to \(Self.sectionCefr[i])"
            }
        }
        return "Up to B2"
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(spacing: 4) {
            if !viewModel.speechService.transcript.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 6) {
                        if let matched = viewModel.speechMatched {
                            if matched {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if !viewModel.isShowingAnswer {
                                // Once the answer is revealed the yellow
                                // warning becomes nagging — the user can see
                                // the real answer above. Keep the green check
                                // around as positive feedback when they
                                // matched.
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text(viewModel.coloredTranscript())
                            .font(.body)
                            .italic()
                    }
                    .frame(maxWidth: .infinity)

                    playbackButton
                    explainButton
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .transition(.opacity)

                if let text = viewModel.explanation {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            } else if viewModel.speechService.lastRecordingURL != nil
                && !viewModel.speechService.isListening {
                // Recorded audio but nothing recognized — let the user still
                // hear themselves.
                HStack {
                    Spacer()
                    playbackButton
                }
                .padding(.horizontal)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .top)
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
            Image(systemName: viewModel.speechService.isPlayingBack
                  ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, isActive: viewModel.speechService.isPlayingBack)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(viewModel.speechService.isPlayingBack ? "Stop playback" : "Play your recording")
    }

    // MARK: - Explain Button

    /// "?" button that asks the on-device LLM why the user's speech-to-text
    /// attempt was wrong. Only shows after a wrong attempt. Hidden once an
    /// explanation has been generated or while one is loading.
    @ViewBuilder
    private var explainButton: some View {
        if viewModel.speechMatched == false,
           viewModel.explanation == nil,
           !viewModel.isLoadingExplanation {
            Button {
                viewModel.requestExplanation()
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityLabel("Explain my mistake")
        } else if viewModel.isLoadingExplanation {
            ProgressView()
                .controlSize(.small)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Action Row

    /// Renders one of three states using a shared button height so the
    /// section doesn't change height when the variant flips:
    /// - Answer hidden: Skip
    /// - Answer shown + speech matched: single Next
    /// - Answer shown + speech mismatch: Got it / Next pair
    @ViewBuilder
    private var actionRow: some View {
        if viewModel.isShowingAnswer {
            if viewModel.speechMatched == true {
                Button {
                    viewModel.rate(quality: 5)
                } label: {
                    actionLabel("Next", bold: true)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                manualRatingButtons
            }
        } else {
            Button {
                viewModel.skip()
            } label: {
                actionLabel("Skip", bold: false)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .padding(.horizontal)
        }
    }

    private func actionLabel(_ title: String, bold: Bool) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(bold ? .bold : .regular)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    private var manualRatingButtons: some View {
        HStack(spacing: 12) {
            // Got it — secondary, subtle green
            Button {
                viewModel.rate(quality: 4)
            } label: {
                actionLabel("Got it", bold: false)
            }
            .buttonStyle(.bordered)
            .tint(.green.opacity(0.6))

            // Didn't get it — primary, subtle red
            Button {
                viewModel.rate(quality: 1)
            } label: {
                actionLabel("Next", bold: true)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}
