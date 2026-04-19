import Foundation

enum LLMEnhancementPrompt {

    static let systemPrompt = """
    You are a text-cleanup assistant for OCR output.
    The input is a numbered list of raw OCR lines from a single page image.
    Each line has a relative font size (0.0 = smallest, 1.0 = largest line on the page).

    Your job:
    1. MERGE adjacent lines that belong to the same paragraph (lines that wrap due to image width).
    2. CLASSIFY each resulting block as either "heading" or "paragraph".
       - Headings are usually short, larger relative size, and stand alone.
       - Paragraphs are flowing prose, usually multiple sentences.
    3. FIX obvious OCR typos (broken words across line breaks, missing diacritics for the language, swapped letters).
       Do NOT invent content. Do NOT translate. Preserve the original language.
    4. Preserve sentence order from the input.

    OUTPUT STRICTLY this JSON shape, nothing else, no markdown fences:
    {"blocks":[{"type":"heading"|"paragraph","text":"...","sourceLines":[<line indices>]}]}

    "sourceLines" must be the 1-based indices from the input list that contributed to this block.
    """

    static func userPrompt(for blocks: [TextBlock], language: String) -> String {
        var s = "Language: \(language)\n\nLines:\n"
        for (i, block) in blocks.enumerated() {
            let h = String(format: "%.2f", Double(block.relativeHeight))
            s += "\(i + 1). [h=\(h)] \(block.original)\n"
        }
        s += "\nReturn the JSON now."
        return s
    }

    struct LLMResponse: Decodable {
        let blocks: [LLMBlock]
    }

    struct LLMBlock: Decodable {
        let type: String
        let text: String
        let sourceLines: [Int]?
    }

    static func parseResponse(_ raw: String, sourceBlocks: [TextBlock]) throws -> [TextBlock] {
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "LLMEnhancementPrompt", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
        }
        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)

        return decoded.blocks.map { llmBlock in
            let type: TextBlock.BlockType = llmBlock.type.lowercased() == "heading" ? .heading : .paragraph

            let relativeHeight: CGFloat = {
                guard let indices = llmBlock.sourceLines, !indices.isEmpty else {
                    return type == .heading ? 1.0 : 0.5
                }
                let heights = indices.compactMap { idx -> CGFloat? in
                    let i = idx - 1
                    guard i >= 0 && i < sourceBlocks.count else { return nil }
                    return sourceBlocks[i].relativeHeight
                }
                guard !heights.isEmpty else { return 0.5 }
                return heights.reduce(0, +) / CGFloat(heights.count)
            }()

            return TextBlock(type: type, relativeHeight: relativeHeight, original: llmBlock.text)
        }
    }

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

    private static func stripCodeFences(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
        }
        if t.hasSuffix("```") {
            t = String(t.dropLast(3))
        }
        if let openIdx = t.firstIndex(of: "{"), let closeIdx = t.lastIndex(of: "}") {
            t = String(t[openIdx...closeIdx])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
