import SwiftUI

/// Displays text as individually tappable words. Tapping a word reveals its
/// Spanish hint(s) above it. When the tapped word is also part of a known
/// two-word phrase in the vocabulary, the phrase translation is shown
/// alongside the single-word hint and the neighbor word is highlighted to
/// indicate the phrase span.
struct TappableWordsView: View {
    let text: String
    let answerText: String
    let font: Font
    let bold: Bool

    @State private var tappedIndex: Int?

    private let resolver = HintResolver()

    private var words: [String] {
        text.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    private var hintResult: HintResult {
        guard let index = tappedIndex else { return .empty }
        return resolver.resolve(forIndex: index, sourceWords: words, answer: answerText)
    }

    var body: some View {
        WrappingHStack(alignment: .center, spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                WordButton(
                    word: word,
                    state: state(at: index),
                    font: font,
                    bold: bold
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tappedIndex = tappedIndex == index ? nil : index
                    }
                }
            }
        }
        // Hints are per-card. When the card advances the view is reused at the
        // same position so @State sticks around; clear on text change.
        .onChange(of: text) { _, _ in
            tappedIndex = nil
        }
    }

    private func state(at index: Int) -> WordState {
        guard let tapped = tappedIndex else { return .idle }
        let result = hintResult

        if index == tapped {
            // Build the stacked label set for the tapped word.
            var labels: [HintLabel] = []

            // Single-word hint (or the proportional fallback) on top, styled
            // as the primary translation.
            if !result.single.isEmpty {
                labels.append(.init(text: result.single.joined(separator: " / "), kind: .single))
            } else if let fb = result.fallback {
                labels.append(.init(text: fb, kind: .single))
            }
            if !result.leftPair.isEmpty {
                labels.append(.init(text: result.leftPair.joined(separator: " / "), kind: .phrase))
            }
            if !result.rightPair.isEmpty {
                labels.append(.init(text: result.rightPair.joined(separator: " / "), kind: .phrase))
            }
            return .tapped(labels: labels)
        }

        // Neighbor of the tapped word that's part of an active phrase. The
        // phrase translation itself is shown above the tapped word; here we
        // just underline the neighbor so the span is visible.
        if index == tapped - 1, !result.leftPair.isEmpty {
            return .phraseNeighbor
        }
        if index == tapped + 1, !result.rightPair.isEmpty {
            return .phraseNeighbor
        }
        return .idle
    }
}

/// Visual state of a word in the tappable layout.
private enum WordState {
    case idle
    case tapped(labels: [HintLabel])
    case phraseNeighbor
}

/// A label rendered above a tapped word. Single translations and phrase
/// translations are styled distinctly so the user can tell them apart.
private struct HintLabel: Hashable {
    let text: String
    let kind: Kind
    enum Kind { case single, phrase }
}

private struct WordButton: View {
    let word: String
    let state: WordState
    let font: Font
    let bold: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            if case .tapped(let labels) = state {
                ForEach(labels, id: \.self) { label in
                    Text(label.text)
                        .font(.caption2)
                        .italic(label.kind == .phrase)
                        .foregroundStyle(label.kind == .single ? Color.accentColor : Color.secondary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            Text(word)
                .font(font)
                .fontWeight(bold ? .bold : .regular)
                .underline(underlineActive, color: underlineColor)
                .onTapGesture(perform: action)
        }
    }

    private var underlineActive: Bool {
        switch state {
        case .idle: return false
        case .tapped, .phraseNeighbor: return true
        }
    }

    private var underlineColor: Color {
        switch state {
        case .idle: return .clear
        case .tapped: return Color.accentColor.opacity(0.4)
        case .phraseNeighbor: return Color.secondary.opacity(0.5)
        }
    }
}

/// A simple wrapping horizontal layout since SwiftUI doesn't have one built-in
struct WrappingHStack: Layout {
    var alignment: HorizontalAlignment = .center
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        var subviewIndex = 0
        for row in rows {
            let xOffset: CGFloat
            switch alignment {
            case .center: xOffset = (bounds.width - row.width) / 2
            case .trailing: xOffset = bounds.width - row.width
            default: xOffset = 0
            }

            var x = bounds.minX + xOffset
            for _ in 0..<row.count {
                let size = subviews[subviewIndex].sizeThatFits(.unspecified)
                subviews[subviewIndex].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                subviewIndex += 1
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var width: CGFloat
        var height: CGFloat
        var count: Int
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row(width: 0, height: 0, count: 0)

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let neededWidth = currentRow.count > 0 ? currentRow.width + spacing + size.width : size.width

            if neededWidth > maxWidth && currentRow.count > 0 {
                rows.append(currentRow)
                currentRow = Row(width: size.width, height: size.height, count: 1)
            } else {
                currentRow.width = neededWidth
                currentRow.height = max(currentRow.height, size.height)
                currentRow.count += 1
            }
        }
        if currentRow.count > 0 {
            rows.append(currentRow)
        }
        return rows
    }
}
