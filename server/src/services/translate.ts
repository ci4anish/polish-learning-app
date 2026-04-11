import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import type { Bindings, TranslateResult } from "../types";
import { GEMINI_BASE_URL, GEMINI_MODEL } from "../lib/constants";

const translateSchema = z.object({
  translation: z.string().describe("Translation of the selected text into Ukrainian"),
});

function buildPrompt(text: string, context?: string): string {
  const parts = [
    `You are a Polish→Ukrainian translator for a Ukrainian-speaking language learner.`,
    ``,
    `Translate the following Polish text into UKRAINIAN (українською мовою): "${text}"`,
  ];
  if (context) {
    parts.push(`It appears in this context: "${context}"`);
  }
  parts.push(
    "",
    "IMPORTANT: The translation MUST be in Ukrainian, NOT in Polish or any other language.",
    "- translation: accurate Ukrainian translation of the Polish text",
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
      max_tokens: 128,
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
      translation: { selectedText: text, translation: parsed.translation },
      provider: "gemini",
      model: GEMINI_MODEL,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("[translate] gemini failed:", message);
    return { success: false, provider: "gemini", model: GEMINI_MODEL, error: message };
  }
}
