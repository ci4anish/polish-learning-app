import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import type { Bindings, OcrResult } from "../types";
import { GEMINI_BASE_URL, GEMINI_MODEL } from "../lib/constants";

const OcrSchema = z.object({
  detectedLanguage: z.string().describe("ISO 639-1 language code of the primary text language"),
  blocks: z.array(
    z.object({
      type: z.enum(["heading", "paragraph"]).describe(
        "heading = titles, all-caps, or prominent standalone lines; paragraph = body text",
      ),
      original: z.string().describe("Original phrase or short clause extracted from the image"),
      translated: z.string().describe("Ukrainian translation of that phrase"),
    }),
  ),
});

function ensureDataUrl(base64Image: string): string {
  if (base64Image.startsWith("data:")) return base64Image;
  return `data:image/jpeg;base64,${base64Image}`;
}

function buildPrompt(languageHint?: string): string {
  const hint = languageHint
    ? `The text is expected to be in "${languageHint}". `
    : "";

  return [
    "You are an OCR + translator creating an interlinear text for a Ukrainian-speaking language learner.",
    "",
    `${hint}Extract all text from this image and translate it into Ukrainian.`,
    "",
    "For each visual block (heading or paragraph) in the image:",
    "1. Split the text into short phrases or clauses (roughly 3-8 words each).",
    "   Break at natural boundaries: prepositions, conjunctions, punctuation, clause edges.",
    "2. For each phrase, output an entry with the original text and its Ukrainian translation.",
    "3. Use type 'heading' for titles, all-caps, or prominent standalone lines; 'paragraph' for body text.",
    "",
    "Text processing rules:",
    "- Reconnect words hyphenated at line breaks (e.g. książ-\\nkę → książkę).",
    "- Remove page numbers.",
    "- Preserve the original language in the 'original' field. Do not rewrite it.",
    "",
    "Translation rules:",
    "- The 'translated' field MUST be in Ukrainian using CYRILLIC script (e.g. 'професії', not 'profesiyi').",
    "- Never transliterate into Latin letters. Always use the Ukrainian Cyrillic alphabet.",
    "- Keep phrases short enough that each pair reads like an interlinear gloss.",
  ].join("\n");
}

export async function performOcr(
  imageBase64: string,
  env: Bindings,
  languageHint?: string,
): Promise<OcrResult> {
  if (!env.GEMINI_API_KEY) {
    return {
      success: false,
      provider: "gemini",
      model: GEMINI_MODEL,
      error: "GEMINI_API_KEY is not configured",
    };
  }

  try {
    const client = new OpenAI({
      apiKey: env.GEMINI_API_KEY,
      baseURL: GEMINI_BASE_URL,
    });

    const response = await client.chat.completions.parse({
      model: GEMINI_MODEL,
      max_tokens: 8192,
      response_format: zodResponseFormat(OcrSchema, "ocr_result"),
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image_url",
              image_url: { url: ensureDataUrl(imageBase64) },
            },
            {
              type: "text",
              text: buildPrompt(languageHint),
            },
          ],
        },
      ],
    });

    const message = response.choices?.[0]?.message;

    if (message?.refusal) {
      return {
        success: false,
        provider: "gemini",
        model: GEMINI_MODEL,
        error: `Model refused: ${message.refusal}`,
      };
    }

    const parsed = message?.parsed;

    if (!parsed || parsed.blocks.length === 0) {
      return {
        success: false,
        provider: "gemini",
        model: GEMINI_MODEL,
        error: "No content extracted from image",
      };
    }

    return {
      success: true,
      content: {
        detectedLanguage: parsed.detectedLanguage,
        blocks: parsed.blocks.map((b) => ({
          type: b.type,
          original: b.original.trim(),
          translated: b.translated.trim(),
        })),
      },
      provider: "gemini",
      model: GEMINI_MODEL,
      usage: response.usage
        ? {
            prompt_tokens: response.usage.prompt_tokens,
            completion_tokens: response.usage.completion_tokens,
            total_tokens: response.usage.total_tokens,
          }
        : undefined,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("[ocr] gemini failed:", message);
    return {
      success: false,
      provider: "gemini",
      model: GEMINI_MODEL,
      error: message,
    };
  }
}
