import SwiftUI

/// Displays text as individually tappable words. Tapping a word reveals its
/// Spanish hint(s) in cells above the row of words. Single-word hints sit in
/// a cell sized to the word; phrase hints sit in a cell spanning all the
/// words they cover. The cell grid is invisible at rest and materializes
/// only when a tap produces hints.
struct TappableWordsView: View {
    let text: String
    let answerText: String
    let font: Font
    let bold: Bool

    @State private var tappedIndex: Int?
    @State private var hintResult: HintResult = .empty

    private let resolver = HintResolver()

    private var words: [String] {
        text.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    var body: some View {
        TappableHintsLayout(
            wordSpacing: 0,
            rowSpacing: 6,
            cellSpacing: 3,
            hintCellHeight: 17,
            horizontalPadding: 10,
            minColumnWidth: 60,
            reservedHintLevels: 2,
            maxCellOverflow: 55
        ) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                WordChip(
                    word: word,
                    isTapped: tappedIndex == index,
                    isPhraseNeighbor: isPhraseNeighbor(at: index),
                    font: font,
                    bold: bold
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tappedIndex = tappedIndex == index ? nil : index
                    }
                }
                .hintRole(.word(index))
            }

            if let tapped = tappedIndex, !hintResult.single.isEmpty {
                HintCell(options: hintResult.single, kind: .single)
                    .hintRole(.singleHint(tapped))
                    .transition(.opacity)
            }

            ForEach(Array(hintResult.phrases.enumerated()), id: \.offset) { _, phrase in
                HintCell(options: phrase.translations, kind: .phrase)
                    .hintRole(.phraseHint(phrase.span))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tappedIndex)
        .onChange(of: text) { _, _ in
            tappedIndex = nil
        }
        .onChange(of: tappedIndex) { _, newIndex in
            if let newIndex {
                hintResult = resolver.resolve(forIndex: newIndex, sourceWords: words, answer: answerText)
            } else {
                hintResult = .empty
            }
        }
    }

    private func isPhraseNeighbor(at index: Int) -> Bool {
        guard tappedIndex != nil else { return false }
        return hintResult.phrases.contains { $0.span.contains(index) }
    }
}

// MARK: - Word chip

private struct WordChip: View {
    let word: String
    let isTapped: Bool
    let isPhraseNeighbor: Bool
    let font: Font
    let bold: Bool
    let action: () -> Void

    var body: some View {
        Text(word)
            .font(font)
            .fontWeight(bold ? .bold : .regular)
            .underline(underlineActive, color: underlineColor)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private var underlineActive: Bool {
        isTapped || isPhraseNeighbor
    }

    private var underlineColor: Color {
        if isTapped { return Color.accentColor.opacity(0.5) }
        if isPhraseNeighbor { return Color.secondary.opacity(0.5) }
        return .clear
    }
}

// MARK: - Hint cell

private struct HintCell: View {
    enum Kind { case single, phrase }

    let options: [String]
    let kind: Kind

    var body: some View {
        Text(options.joined(separator: " / "))
            .font(.caption2)
            .italic(kind == .phrase)
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(strokeColor, lineWidth: 0.5)
            )
    }

    private var textColor: Color {
        kind == .single ? Color.accentColor : Color.secondary
    }

    private var fillColor: Color {
        switch kind {
        case .single: return Color.accentColor.opacity(0.06)
        case .phrase: return Color.secondary.opacity(0.06)
        }
    }

    private var strokeColor: Color {
        switch kind {
        case .single: return Color.accentColor.opacity(0.35)
        case .phrase: return Color.secondary.opacity(0.4)
        }
    }
}

// MARK: - Layout

/// What role a subview plays inside `TappableHintsLayout`.
private enum HintRole: Equatable {
    case word(Int)
    case singleHint(Int)              // hint for the word at this index
    case phraseHint(ClosedRange<Int>) // hint spanning this word-index range
}

private struct HintRoleKey: LayoutValueKey {
    static let defaultValue: HintRole = .word(.min)
}

extension View {
    fileprivate func hintRole(_ role: HintRole) -> some View {
        layoutValue(key: HintRoleKey.self, value: role)
    }
}

/// Lays out a wrapping row of words with hint cells stacked above each row.
///
/// Per row:
/// - One row per matched phrase hint (sized to span the words it covers).
///   The first hint from the resolver sits closest to the words.
/// - One row of single-word hint cells, each sized to its word's width.
/// - The words themselves, with `wordSpacing` between them.
///
/// Phrases that span words across a wrap boundary are skipped — they have no
/// natural single-cell representation.
struct TappableHintsLayout: Layout {
    var wordSpacing: CGFloat = 0
    var rowSpacing: CGFloat = 8
    var cellSpacing: CGFloat = 4
    var hintCellHeight: CGFloat = 22
    /// Extra horizontal padding around each word that hint cells can occupy.
    /// Each word's column width = max(word width + 2 * horizontalPadding,
    /// minColumnWidth).
    var horizontalPadding: CGFloat = 10
    /// Minimum column width — short words (e.g. "a", "I") get this so the
    /// hint cell has room even when the word itself is narrower.
    var minColumnWidth: CGFloat = 60
    /// Number of hint-cell rows always reserved above each row of words so
    /// the words don't shift down when hints appear. Cells stack bottom-up
    /// inside this reserved area; if the actual stack exceeds it, the area
    /// grows.
    var reservedHintLevels: Int = 2
    /// How far a hint cell may extend past its natural column/span width
    /// when its content is wider than the column. Half of this extends on
    /// each side, so neighbors with no active cells aren't visibly intruded
    /// upon for short overflows.
    var maxCellOverflow: CGFloat = 30

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        compute(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = compute(proposal: proposal, subviews: subviews)
        for placement in result.placements {
            subviews[placement.subviewIndex].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private struct Placement {
        let subviewIndex: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGSize
    }

    private struct LayoutResult {
        let size: CGSize
        let placements: [Placement]
    }

    private struct WordInfo {
        let wordIndex: Int
        let subviewIndex: Int
        let size: CGSize
    }

    private struct PhraseInfo {
        let range: ClosedRange<Int>
        let subviewIndex: Int
    }

    private func compute(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        var words: [WordInfo] = []
        var singleHints: [Int: Int] = [:]            // word index -> subview index
        var phraseHints: [PhraseInfo] = []

        for (i, subview) in subviews.enumerated() {
            let role = subview[HintRoleKey.self]
            switch role {
            case .word(let idx):
                guard idx >= 0 else { continue }
                let size = subview.sizeThatFits(.unspecified)
                words.append(WordInfo(wordIndex: idx, subviewIndex: i, size: size))
            case .singleHint(let idx):
                singleHints[idx] = i
            case .phraseHint(let range):
                phraseHints.append(PhraseInfo(range: range, subviewIndex: i))
            }
        }
        words.sort { $0.wordIndex < $1.wordIndex }

        // Each word's "column" is wider than the word — the extra width is
        // where hint cells live. Words center inside their column. Short
        // words get bumped up to minColumnWidth so their hint cell isn't
        // squeezed to a sliver.
        func columnWidth(for word: WordInfo) -> CGFloat {
            max(word.size.width + 2 * horizontalPadding, minColumnWidth)
        }

        let maxWidth = proposal.width ?? .infinity

        // Wrap into rows based on column widths.
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0
        for (i, w) in words.enumerated() {
            let colW = columnWidth(for: w)
            let needed = current.isEmpty ? colW : currentWidth + wordSpacing + colW
            if needed > maxWidth && !current.isEmpty {
                rows.append(current)
                current = [i]
                currentWidth = colW
            } else {
                current.append(i)
                currentWidth = needed
            }
        }
        if !current.isEmpty {
            rows.append(current)
        }

        let reservedHintHeight = CGFloat(reservedHintLevels) * hintCellHeight
            + CGFloat(max(reservedHintLevels - 1, 0)) * cellSpacing

        var placements: [Placement] = []
        var cursorY: CGFloat = 0

        for row in rows {
            let rowWords = row.map { words[$0] }
            let rowTotalWidth = rowWords.map(columnWidth).reduce(0, +)
                + CGFloat(max(rowWords.count - 1, 0)) * wordSpacing
            let xOffset: CGFloat = maxWidth.isFinite
                ? max(0, (maxWidth - rowTotalWidth) / 2)
                : 0

            // Record each word's column geometry.
            struct ColRect { let x: CGFloat; let columnWidth: CGFloat; let wordWidth: CGFloat }
            var columns: [Int: ColRect] = [:]
            var x = xOffset
            var wordHeight: CGFloat = 0
            for w in rowWords {
                let cw = columnWidth(for: w)
                columns[w.wordIndex] = ColRect(x: x, columnWidth: cw, wordWidth: w.size.width)
                wordHeight = max(wordHeight, w.size.height)
                x += cw + wordSpacing
            }

            let rowWordSet = Set(rowWords.map(\.wordIndex))
            let rowPhrases = phraseHints.filter { phrase in
                phrase.range.allSatisfy { rowWordSet.contains($0) }
            }
            let rowSingles: [(wordIdx: Int, subviewIdx: Int)] = rowWords.compactMap { w in
                guard let sub = singleHints[w.wordIndex] else { return nil }
                return (w.wordIndex, sub)
            }

            // Build the hint-cell stack for this row. Order is top-to-bottom:
            // phrase matches (in reverse resolver order so the first/closest
            // match sits nearest the words), then the single-hint row.
            struct CellPlacement {
                let subviewIndex: Int
                let x: CGFloat
                let width: CGFloat
                let height: CGFloat
            }
            var hintCells: [CellPlacement] = []

            // Sizes a cell at most maxCellOverflow wider than its base width,
            // centered on the base region. If the cell's natural single-line
            // content is narrower than base, it still uses base width so it
            // aligns with the word/span below.
            func sizeCell(subviewIndex: Int, baseX: CGFloat, baseWidth: CGFloat) -> CellPlacement {
                let natural = subviews[subviewIndex].sizeThatFits(.unspecified)
                let preferredWidth = max(baseWidth, min(natural.width, baseWidth + maxCellOverflow))
                let measured = subviews[subviewIndex]
                    .sizeThatFits(ProposedViewSize(width: preferredWidth, height: nil))
                let cellHeight = max(measured.height, hintCellHeight)
                let cellX = baseX + (baseWidth - preferredWidth) / 2
                return CellPlacement(
                    subviewIndex: subviewIndex,
                    x: cellX,
                    width: preferredWidth,
                    height: cellHeight
                )
            }

            for phrase in rowPhrases.reversed() {
                guard let start = columns[phrase.range.lowerBound],
                      let end = columns[phrase.range.upperBound] else { continue }
                let spanX = start.x
                let spanWidth = (end.x + end.columnWidth) - start.x
                hintCells.append(sizeCell(
                    subviewIndex: phrase.subviewIndex,
                    baseX: spanX,
                    baseWidth: spanWidth
                ))
            }

            for single in rowSingles {
                let col = columns[single.wordIdx]!
                hintCells.append(sizeCell(
                    subviewIndex: single.subviewIdx,
                    baseX: col.x,
                    baseWidth: col.columnWidth
                ))
            }

            let actualStackHeight = hintCells.map(\.height).reduce(0, +)
                + CGFloat(max(hintCells.count - 1, 0)) * cellSpacing
            let hintAreaHeight = max(actualStackHeight, reservedHintHeight)

            // Place cells bottom-aligned in the hint area so the stack always
            // sits just above the words. Extra reserved space falls at the top.
            var cellY = cursorY + (hintAreaHeight - actualStackHeight)
            for cell in hintCells {
                placements.append(Placement(
                    subviewIndex: cell.subviewIndex,
                    x: cell.x,
                    y: cellY,
                    size: CGSize(width: cell.width, height: cell.height)
                ))
                cellY += cell.height + cellSpacing
            }

            // Words sit below the hint area, centered in their column.
            let wordY = cursorY + hintAreaHeight + cellSpacing
            for w in rowWords {
                let col = columns[w.wordIndex]!
                let wordX = col.x + (col.columnWidth - col.wordWidth) / 2
                placements.append(Placement(
                    subviewIndex: w.subviewIndex,
                    x: wordX,
                    y: wordY,
                    size: w.size
                ))
            }

            cursorY = wordY + wordHeight + rowSpacing
        }

        // Mirror the reserved hint area above the first row with the same
        // amount of empty space below the last row, so the whole block sits
        // vertically symmetric inside its container.
        let bottomPadding = reservedHintHeight + cellSpacing
        let totalHeight = max(cursorY - rowSpacing, 0) + bottomPadding
        let totalWidth: CGFloat
        if maxWidth.isFinite {
            totalWidth = maxWidth
        } else {
            totalWidth = rows.map { row in
                row.map { columnWidth(for: words[$0]) }.reduce(0, +)
                    + CGFloat(max(row.count - 1, 0)) * wordSpacing
            }.max() ?? 0
        }

        // Any subview that didn't get a placement above (most commonly a
        // phrase hint whose span crosses a wrap boundary, which we
        // deliberately skip per-row) gets parked far offscreen with zero
        // size. Without this, SwiftUI's Layout protocol leaves unplaced
        // subviews at (0, 0) at their natural size — they're invisible
        // there but still intercept taps on the first word.
        let placedIndices = Set(placements.map(\.subviewIndex))
        for i in 0..<subviews.count where !placedIndices.contains(i) {
            placements.append(Placement(
                subviewIndex: i,
                x: -10_000,
                y: -10_000,
                size: .zero
            ))
        }

        return LayoutResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            placements: placements
        )
    }
}
