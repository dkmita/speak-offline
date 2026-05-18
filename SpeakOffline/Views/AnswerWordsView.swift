import SwiftUI

/// Renders a Spanish answer with each word's phonetic guide stacked directly
/// underneath it, column-aligned. Phonetics are always visible (no tap
/// required) and the cells have no borders — they're just text in a wrapping
/// row layout.
///
/// Phonetics are assumed to be space-separated 1:1 with the answer words.
/// Excess words on either side are rendered without their counterpart rather
/// than dropping silently.
struct AnswerWordsView: View {
    let text: String
    let phonetic: String?
    let font: Font

    @StateObject private var tts = SpanishTTSService.shared

    private var pairs: [(word: String, phonetic: String?)] {
        let words = text.components(separatedBy: " ").filter { !$0.isEmpty }
        let phoneticWords = (phonetic ?? "")
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        return words.enumerated().map { i, w in
            (w, i < phoneticWords.count ? phoneticWords[i] : nil)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            WordPhoneticRow(wordSpacing: 6, lineSpacing: 4) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 1) {
                        Text(pair.word)
                            .font(font)
                        if let phon = pair.phonetic {
                            Text(phon)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                if tts.isSpeaking {
                    tts.stop()
                } else {
                    tts.speak(text)
                }
            } label: {
                Image(systemName: tts.isSpeaking
                      ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, isActive: tts.isSpeaking)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(tts.isSpeaking ? "Stop audio" : "Play Spanish audio")
        }
    }
}

/// Wraps subviews to fit the proposed width, centering each row. Used by
/// `AnswerWordsView` so word/phonetic pairs stay together as they wrap.
private struct WordPhoneticRow: Layout {
    var wordSpacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        var i = 0
        for row in rows {
            let leading = max(0, (bounds.width - row.width) / 2)
            var x = bounds.minX + leading
            for _ in 0..<row.count {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + wordSpacing
                i += 1
            }
            y += row.height + lineSpacing
        }
    }

    private struct RowInfo {
        var width: CGFloat
        var height: CGFloat
        var count: Int
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [RowInfo] {
        var rows: [RowInfo] = []
        var cur = RowInfo(width: 0, height: 0, count: 0)
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = cur.count == 0 ? size.width : cur.width + wordSpacing + size.width
            if needed > maxWidth && cur.count > 0 {
                rows.append(cur)
                cur = RowInfo(width: size.width, height: size.height, count: 1)
            } else {
                cur.width = needed
                cur.height = max(cur.height, size.height)
                cur.count += 1
            }
        }
        if cur.count > 0 { rows.append(cur) }
        return rows
    }
}
