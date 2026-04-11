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
      text: z.string().describe(
        "Extracted text with line-break hyphens reconnected (e.g. książ-\\nkę → książkę) and page numbers removed",
      ),
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
    "Extract all text from this image into structured blocks.",
    "",
    `${hint}Preserve the original language. Do not translate or summarize.`,
    "Merge consecutive lines belonging to the same paragraph.",
    "Reconnect words hyphenated at line breaks.",
    "Remove page numbers.",
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
      max_tokens: 4096,
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
        blocks: parsed.blocks.map((b: z.infer<typeof OcrSchema>["blocks"][number]) => ({
          type: b.type,
          text: b.text.trim(),
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
