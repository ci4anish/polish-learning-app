import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import type { Bindings, TranslateResult } from "../types";
import { GEMINI_BASE_URL, GEMINI_MODEL } from "../lib/constants";

const translateSchema = z.object({
  translation: z.string().describe("Translation of the selected text into Ukrainian"),
  partOfSpeech: z.string().describe("Part of speech in Ukrainian with the native Polish grammar term in parentheses, e.g. 'Прикметник (Przymiotnik)'"),
});

function buildPrompt(text: string, context?: string): string {
  const parts = [
    `Translate the following Polish text for a language learner: "${text}"`,
  ];
  if (context) {
    parts.push(`It appears in this context: "${context}"`);
  }
  parts.push(
    "",
    "Provide in Ukrainian:",
    "- Accurate translation",
    "- Part of speech with the native Polish grammar term in parentheses",
  );
  return parts.join("\n");
}

export async function performTranslate(
  text: string,
  env: Bindings,
  context?: string,
): Promise<TranslateResult> {
  if (!env.GEMINI_API_KEY) {
    return { success: false, provider: "gemini", model: GEMINI_MODEL, error: "GEMINI_API_KEY is not configured" };
  }

  try {
    const client = new OpenAI({ apiKey: env.GEMINI_API_KEY, baseURL: GEMINI_BASE_URL });

    const response = await client.chat.completions.parse({
      model: GEMINI_MODEL,
      max_tokens: 512,
      response_format: zodResponseFormat(translateSchema, "translation"),
      messages: [{ role: "user", content: buildPrompt(text, context) }],
    });

    const message = response.choices?.[0]?.message;
    if (message?.refusal) {
      return { success: false, provider: "gemini", model: GEMINI_MODEL, error: `Model refused: ${message.refusal}` };
    }

    const parsed = message?.parsed;
    if (!parsed) {
      return { success: false, provider: "gemini", model: GEMINI_MODEL, error: "Failed to parse translation from model" };
    }

    return {
      success: true,
      translation: { selectedText: text, translation: parsed.translation, partOfSpeech: parsed.partOfSpeech },
      provider: "gemini",
      model: GEMINI_MODEL,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("[translate] gemini failed:", message);
    return { success: false, provider: "gemini", model: GEMINI_MODEL, error: message };
  }
}
