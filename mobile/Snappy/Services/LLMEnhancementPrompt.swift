import Foundation

enum LLMEnhancementPrompt {

    // MARK: - Classification (heading vs paragraph)

    static let classificationSystemPrompt = """
    You classify text blocks from a scanned page as either heading or paragraph.

    Definitions:
    - heading: a title, chapter name, section title, or short standalone label.
      Usually short (a few words), often larger font, often centred or bold,
      rarely ends with a period.
    - paragraph: flowing prose, usually one or more full sentences.

    You will receive a numbered list of blocks. Each block has its relative
    font size (h, where 1.00 is the largest line on the page).

    Respond with EXACTLY one character per block, in order, with no separators
    and no other text:
      H = heading
      P = paragraph

    Example input:
      1. [h=1.00] Rozdział pierwszy
      2. [h=0.42] Było to późnym wieczorem, gdy ktoś zapukał do drzwi.
      3. [h=0.42] Marek wstał i poszedł otworzyć.
      4. [h=0.78] Niespodziewany gość

    Example output:
      HPPH
    """

    static func classificationUserPrompt(for blocks: [TextBlock]) -> String {
        var s = "Blocks:\n"
        for (i, block) in blocks.enumerated() {
            let h = String(format: "%.2f", Double(block.relativeHeight))
            let preview = block.original
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(160)
            s += "\(i + 1). [h=\(h)] \(preview)\n"
        }
        s += "\nAnswer with \(blocks.count) characters (H or P), nothing else."
        return s
    }

    /// Parses the model's raw output into one `BlockType` per input block.
    /// Tolerates whitespace, extra commentary, lowercase, and short answers
    /// (missing positions default to `.paragraph`).
    static func parseClassification(_ raw: String, expectedCount: Int) -> [TextBlock.BlockType] {
        let letters = raw.uppercased().compactMap { ch -> Character? in
            (ch == "H" || ch == "P") ? ch : nil
        }

        var result: [TextBlock.BlockType] = []
        result.reserveCapacity(expectedCount)
        for i in 0..<expectedCount {
            if i < letters.count {
                result.append(letters[i] == "H" ? .heading : .paragraph)
            } else {
                result.append(.paragraph)
            }
        }
        return result
    }

    // MARK: - Translation refinement (unchanged)

    static let translationSystemPrompt = """
    You are a professional translator that refines machine-translation output.
    You will receive:
    - source_language, target_language
    - selection: the exact phrase the user wants translated
    - context: the full sentence or paragraph the selection comes from (may equal the selection)
    - draft_translation: a translation of the selection produced by Apple's on-device translator

    Your job: produce a SINGLE improved translation of the SELECTION into target_language, using the context to disambiguate meaning, gender, register, idioms, and grammar. Stay faithful to the source meaning. Do NOT translate the whole context — only the selection.

    Rules:
    - Output ONLY the final improved translation as plain text on one line.
    - No quotes, no markdown, no commentary, no explanations, no language tags.
    - If the draft is already correct, you may return it unchanged.
    - Match the form of the selection: word -> word, phrase -> phrase, sentence -> sentence.
    """

    static func translationUserPrompt(
        selection: String,
        context: String?,
        draft: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        var s = "source_language: \(sourceLanguage)\n"
        s += "target_language: \(targetLanguage)\n"
        s += "selection: \(selection)\n"
        if let context, !context.isEmpty, context != selection {
            s += "context: \(context)\n"
        }
        s += "draft_translation: \(draft)\n"
        s += "\nReturn the improved translation now."
        return s
    }

    static func sanitizeTranslation(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if t.hasSuffix("```") { t = String(t.dropLast(3)) }
        }
        if let firstLine = t.split(whereSeparator: { $0.isNewline }).first {
            t = String(firstLine)
        }
        let trimChars = CharacterSet(charactersIn: "\"'`«»“”„ \t")
        t = t.trimmingCharacters(in: trimChars)
        return t
    }
}
