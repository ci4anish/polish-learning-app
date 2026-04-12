import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import type { Bindings, OcrResult, TextBlock } from "../types";
import { GEMINI_BASE_URL, GEMINI_OCR_MODEL } from "../lib/constants";

const OcrSchema = z.object({
  detectedLanguage: z.string().describe("ISO 639-1 language code of the primary text language"),
  blocks: z.array(
    z.object({
      type: z.enum(["heading", "paragraph"]).describe(
        "heading = titles, all-caps, or prominent standalone lines; paragraph = body text",
      ),
      original: z.string().describe("Full paragraph text with line breaks joined into flowing prose"),
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
    "You are an OCR engine extracting text from a photo of an open book for a language learner.",
    "",
    `${hint}Focus ONLY on the single central page the camera is pointed at. Ignore the opposite page, page numbers, headers, footers, marginalia, watermarks, and any text visible at the edges that belongs to another page.`,
    "",
    "Rules:",
    "- Output blocks in the same order they appear on the page, top to bottom.",
    "- Each block must map to one visual paragraph or heading as laid out on the page. Preserve the paragraph structure of the original layout.",
    "- Merge all printed lines within the same paragraph into ONE block — do NOT create separate blocks for individual lines.",
    "- Join hyphenated words that wrap across lines (e.g. 'wiedź-\\nmin' → 'wiedźmin').",
    "- Replace in-line line breaks with spaces so each block reads as continuous flowing text.",
    "- Preserve the original language exactly. Do not translate, rewrite, or correct spelling.",
    "- Use type 'heading' for chapter titles, all-caps, or prominent standalone lines; 'paragraph' for body text.",
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
      model: GEMINI_OCR_MODEL,
      error: "GEMINI_API_KEY is not configured",
    };
  }

  try {
    const client = new OpenAI({
      apiKey: env.GEMINI_API_KEY,
      baseURL: GEMINI_BASE_URL,
    });

    const response = await client.chat.completions.parse({
      model: GEMINI_OCR_MODEL,
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
        model: GEMINI_OCR_MODEL,
        error: `Model refused: ${message.refusal}`,
      };
    }

    const parsed = message?.parsed;

    if (!parsed || parsed.blocks.length === 0) {
      return {
        success: false,
        provider: "gemini",
        model: GEMINI_OCR_MODEL,
        error: "No content extracted from image",
      };
    }

    return {
      success: true,
      content: {
        detectedLanguage: parsed.detectedLanguage,
        blocks: parsed.blocks.map((b) => ({
          type: b.type,
          original: b.original.replace(/\n/g, " ").replace(/\s+/g, " ").trim(),
        })),
      },
      provider: "gemini",
      model: GEMINI_OCR_MODEL,
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
      model: GEMINI_OCR_MODEL,
      error: message,
    };
  }
}

