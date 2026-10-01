import Foundation

/// One sentence of a page read aloud: where it sits on the page, counted in characters as
/// `PageVaultSearch` counts them, so the reader can tint it, and the cleaned words actually spoken.
struct PageVaultSpeechSegment: Equatable {
    var page: Int
    var offset: Int
    var length: Int
    var spoken: String

    var mark: PageVaultFindMark { PageVaultFindMark(page: page, offset: offset, length: length) }
}

/// Turns a page's text layer into sentences worth speaking.
///
/// PDF text arrives one printed line at a time, with running headers, footers and page numbers at
/// the edges and words hyphenated across line ends. This leaves out the edges that repeat on nearby
/// pages or are only a number, joins lines back into sentences, and gives each sentence both its
/// place on the page and a clean spoken form.
enum PageVaultReadAloud {
    /// How many lines at the top and at the bottom of a page can be a header, footer or number.
    static let edgeLineCount = 2
    /// Nearby pages compared for repeated edges, on each side.
    static let neighbourReach = 2

    struct Line: Equatable {
        /// Character offset of the line's first character in the page text.
        var offset: Int
        var text: String
        var length: Int { text.count }
    }

    /// The page's non-blank lines with their positions.
    static func lines(_ text: String) -> [Line] {
        var result: [Line] = []
        var current = ""
        var start = 0
        var position = 0
        for character in text {
            if character.isNewline {
                result.append(Line(offset: start, text: current))
                current = ""
                start = position + 1
            } else {
                current.append(character)
            }
            position += 1
        }
        result.append(Line(offset: start, text: current))
        return result.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// A line reduced to its letters, lowercased, so "Chapter 3 · The Habit Loop 47" on one page and
    /// "Chapter 3 · The Habit Loop 48" on the next compare equal.
    static func edgeKey(_ line: String) -> String {
        String(line.lowercased().filter(\.isLetter))
    }

    /// The keys of a page's top and bottom lines, for comparing with nearby pages.
    static func edgeKeys(_ text: String) -> [String] {
        let all = lines(text)
        let edges = all.prefix(edgeLineCount) + all.suffix(edgeLineCount)
        return edges.map { edgeKey($0.text) }.filter { !$0.isEmpty }
    }

    /// A number, a roman numeral or an ornament on its own, such as a page number.
    static func isPageNumberLike(_ line: String) -> Bool {
        let key = edgeKey(line)
        return key.isEmpty || (key.count <= 6 && key.allSatisfy { "ivxlcdm".contains($0) })
    }

    /// The character range between any running header and footer, or nil when nothing on the page
    /// is worth reading. `neighbours` holds the edge keys of nearby pages: a top or bottom line that
    /// also sits at the edge of one of them is a running header or footer.
    static func readableRange(_ text: String, neighbours: [[String]]) -> Range<Int>? {
        var kept = lines(text)
        func isClutter(_ line: Line) -> Bool {
            if isPageNumberLike(line.text) { return true }
            let key = edgeKey(line.text)
            return neighbours.contains { $0.contains(key) }
        }
        var dropped = 0
        while let first = kept.first, dropped < edgeLineCount, isClutter(first) {
            kept.removeFirst()
            dropped += 1
        }
        dropped = 0
        while let last = kept.last, dropped < edgeLineCount, isClutter(last) {
            kept.removeLast()
            dropped += 1
        }
        guard let first = kept.first, let last = kept.last else { return nil }
        return first.offset..<(last.offset + last.length)
    }

    /// The page as sentences to speak, in reading order.
    static func segments(page: Int, text: String, neighbours: [[String]]) -> [PageVaultSpeechSegment] {
        guard let range = readableRange(text, neighbours: neighbours) else { return [] }
        let characters = Array(text)
        let region = Array(characters[range])
        let boundaries = String(sentenceText(region))

        var result: [PageVaultSpeechSegment] = []
        boundaries.enumerateSubstrings(in: boundaries.startIndex..<boundaries.endIndex,
                                       options: .bySentences) { substring, found, _, _ in
            guard let substring else { return }
            let leading = substring.prefix { $0.isWhitespace }.count
            let trailing = substring.reversed().prefix { $0.isWhitespace }.count
            let length = substring.count - leading - trailing
            guard length > 0 else { return }
            let start = boundaries.distance(from: boundaries.startIndex, to: found.lowerBound) + leading
            let original = String(region[start..<(start + length)])
            let spoken = spokenText(original)
            guard spoken.contains(where: { $0.isLetter || $0.isNumber }) else { return }
            result.append(PageVaultSpeechSegment(page: page, offset: range.lowerBound + start,
                                                 length: length, spoken: spoken))
        }
        return result
    }

    /// The region with line breaks turned into spaces, one character for one so offsets still line
    /// up, except where a line is clearly shorter than the page's lines: the end of a paragraph or a
    /// heading, which keeps its break so it is not run into the next sentence.
    static func sentenceText(_ region: [Character]) -> [Character] {
        let text = String(region)
        let all = lines(text)
        // A full line of this page's type: the upper quartile, so a few short lines cannot drag it down.
        let widths = all.map(\.length).sorted()
        let typical = widths.isEmpty ? 0 : widths[widths.count * 3 / 4]
        var keptBreaks = Set<Int>()
        for line in all where Double(line.length) < Double(typical) * 0.6 {
            keptBreaks.insert(line.offset + line.length)
        }
        return region.enumerated().map { index, character in
            guard character.isNewline else { return character }
            return keptBreaks.contains(index) ? "\n" : " "
        }
    }

    private static let ligatures: [Character: String] = [
        "\u{FB00}": "ff", "\u{FB01}": "fi", "\u{FB02}": "fl", "\u{FB03}": "ffi", "\u{FB04}": "ffl"
    ]

    /// What the voice says: words hyphenated across a line end joined again, ligatures spelled out,
    /// soft hyphens dropped and every run of space or line break made one space.
    static func spokenText(_ original: String) -> String {
        var output = ""
        let characters = Array(original)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            // "inter-" at a line end followed by "national": one word again.
            if character == "-", index + 1 < characters.count, characters[index + 1].isNewline,
               index > 0, characters[index - 1].isLetter,
               index + 2 < characters.count, characters[index + 2].isLowercase {
                index += 2
                continue
            }
            if character == "\u{00AD}" { index += 1; continue }
            if let spelled = ligatures[character] {
                output += spelled
            } else if character.isWhitespace {
                if output.last != " " { output.append(" ") }
            } else {
                output.append(character)
            }
            index += 1
        }
        return output.trimmingCharacters(in: .whitespaces)
    }
}
