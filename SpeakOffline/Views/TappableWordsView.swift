import SwiftUI

/// Displays text as individually tappable words. Tapping a word shows
/// the corresponding word(s) from the answer phrase in a popover.
struct TappableWordsView: View {
    let text: String
    let answerText: String
    let font: Font
    let bold: Bool

    @State private var tappedIndex: Int?

    private var words: [String] {
        text.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    private var answerWords: [String] {
        answerText.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    var body: some View {
        WrappingHStack(alignment: .center, spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                WordButton(
                    word: word,
                    hint: hintFor(index: index),
                    isRevealed: tappedIndex == index,
                    font: font,
                    bold: bold
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tappedIndex = tappedIndex == index ? nil : index
                    }
                }
            }
        }
    }

    /// Map an English word index to the corresponding Spanish word(s)
    /// using proportional position mapping
    private func hintFor(index: Int) -> String {
        let srcCount = words.count
        let dstCount = answerWords.count
        guard dstCount > 0, srcCount > 0 else { return "?" }

        // Map source index range to destination index range proportionally
        let ratio = Double(dstCount) / Double(srcCount)
        let startIdx = Int((Double(index) * ratio).rounded(.down))
        let endIdx = Int((Double(index + 1) * ratio).rounded(.up)) - 1

        let clamped = max(0, startIdx)...min(dstCount - 1, max(startIdx, endIdx))
        return answerWords[clamped].joined(separator: " ")
    }
}

private struct WordButton: View {
    let word: String
    let hint: String
    let isRevealed: Bool
    let font: Font
    let bold: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            if isRevealed {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Text(word)
                .font(font)
                .fontWeight(bold ? .bold : .regular)
                .underline(isRevealed, color: Color.accentColor.opacity(0.4))
                .onTapGesture(perform: action)
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
