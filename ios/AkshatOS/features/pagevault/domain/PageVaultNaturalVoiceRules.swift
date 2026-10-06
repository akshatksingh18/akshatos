import Foundation

/// The rules behind the natural (neural) read-aloud voice, kept free of the engine so they can be
/// tested anywhere: which files an imported voice folder needs, which voices it holds, how a page's
/// passage is cut into pieces for the engine, and how a speed test reads.
enum PageVaultNaturalVoiceRules {
    /// What a Kokoro folder from sherpa-onnx (`kokoro-int8-multi-lang-v1_0`) must contain, besides
    /// the model itself.
    static let requiredItems = ["voices.bin", "tokens.txt", "lexicon-us-en.txt", "espeak-ng-data"]
    /// The model file: the compressed (int8) download names it `model.int8.onnx`, the full one
    /// `model.onnx`. Either works; the compressed one is used when both are there.
    static let modelNames = ["model.int8.onnx", "model.onnx"]

    static func modelFile(in present: Set<String>) -> String? {
        modelNames.first { present.contains($0) }
    }
    /// The voice offered until Akshat picks another: Heart, the one Kokoro's authors rate best.
    static let defaultSpeaker = 3
    /// Audio the engine produces, in samples per second.
    static let sampleRate = 24_000.0
    /// Pieces rendered ahead of the one playing, so the next sentence is ready when one ends.
    static let lookahead = 3

    struct Speaker: Equatable, Identifiable {
        let id: Int
        let name: String
        let accent: String
        let voice: String
        var label: String { "\(name) · \(accent), \(voice)" }
    }

    /// The English voices in Kokoro v1.0, by speaker id.
    static let speakers: [Speaker] = {
        let names = ["af_alloy", "af_aoede", "af_bella", "af_heart", "af_jessica", "af_kore", "af_nicole",
                     "af_nova", "af_river", "af_sarah", "af_sky", "am_adam", "am_echo", "am_eric",
                     "am_fenrir", "am_liam", "am_michael", "am_onyx", "am_puck", "am_santa",
                     "bf_alice", "bf_emma", "bf_isabella", "bf_lily", "bm_daniel", "bm_fable",
                     "bm_george", "bm_lewis"]
        return names.enumerated().map { id, code in
            let prefix = code.prefix(2)
            let name = code.dropFirst(3).prefix(1).uppercased() + code.dropFirst(4)
            return Speaker(id: id, name: name,
                           accent: prefix.first == "a" ? "American" : "British",
                           voice: prefix.last == "f" ? "female" : "male")
        }
    }()

    static func speaker(_ id: Int) -> Speaker? { speakers.first { $0.id == id } }

    /// Which required items an imported folder lacks, by name.
    static func missing(from present: Set<String>) -> [String] {
        (modelFile(in: present) == nil ? ["model.int8.onnx"] : []) + requiredItems.filter { !present.contains($0) }
    }

    /// One piece of a passage for the engine, and where it starts in the passage (UTF-16), which is
    /// what moves the tint when it starts playing.
    struct Piece: Equatable {
        var text: String
        var utf16: Int
    }

    /// A page's passage cut at its sentence starts: one piece per sentence. Words carried over from
    /// the previous page are joined to the first sentence, so a sentence running over a page break
    /// is still said in one go; that piece tints the first sentence.
    static func pieces(of plan: PageVaultSpeechPlan) -> [Piece] {
        let text = Array(plan.text.utf16)
        var result: [Piece] = []
        for (position, start) in plan.starts.enumerated() {
            let end = position + 1 < plan.starts.count ? plan.starts[position + 1].utf16 : text.count
            guard start.utf16 < end, end <= text.count else { continue }
            let slice = String(decoding: text[start.utf16..<end], as: UTF16.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slice.isEmpty else { continue }
            result.append(Piece(text: slice, utf16: start.utf16))
        }
        if plan.starts.first?.segment == nil, result.count > 1 {
            let carried = result.removeFirst()
            result[0].text = carried.text + " " + result[0].text
        }
        return result
    }

    /// How many seconds a run of samples plays for.
    static func seconds(ofSamples count: Int) -> Double { Double(count) / sampleRate }

    /// "11.2 s of speech in 1.4 s · 8.0× faster than real time · first sentence after 0.6 s".
    /// Faster than real time is what reading needs: below 1× the voice would stall between sentences.
    static func speedSummary(audio: Double, render: Double, firstPiece: Double) -> String {
        guard audio > 0, render > 0 else { return "The test produced no audio." }
        let factor = audio / render
        let verdict = factor >= 1.5 ? "fast enough to read without gaps"
            : factor >= 1 ? "only just keeps up; expect short gaps at 1.5× and above"
            : "too slow: reading will pause between sentences"
        return String(format: "%.1f s of speech in %.1f s · %.1f× real time · first sentence after %.1f s",
                      audio, render, factor, firstPiece) + " · " + verdict
    }
}
