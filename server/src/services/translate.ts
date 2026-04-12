import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import type { Bindings, TranslateResult } from "../types";
import { GEMINI_BASE_URL, GEMINI_MODEL } from "../lib/constants";

const TranslateSchema = z.object({
  translated: z.string().describe("The Ukrainian (Cyrillic) translation of the input text"),
});

const SYSTEM_PROMPT = [
  "You are a professional translator. Your ONLY job is to translate text into Ukrainian.",
  "You MUST output Ukrainian text using Cyrillic script (е.g. А, Б, В, Г…).",
  "NEVER repeat the original text. NEVER transliterate into Latin letters.",
  "Provide a natural, fluent, contextually appropriate Ukrainian translation.",
].join(" ");

function buildUserPrompt(text: string, context?: string, sourceLanguage?: string): string {
  const parts: string[] = [];

  if (sourceLanguage) {
    parts.push(`Source language: ${sourceLanguage}`);
  }

  if (context && context !== text) {
    parts.push(`Context: «${context}»`);
  }

  parts.push(`Translate into Ukrainian: «${text}»`);

  return parts.join("\n");
}

export async function performTranslation(
  text: string,
  env: Bindings,
  context?: string,
  sourceLanguage?: string,
): Promise<TranslateResult> {
  if (!env.GEMINI_API_KEY) {
    return { success: false, error: "GEMINI_API_KEY is not configured" };
  }

  try {
    const client = new OpenAI({
      apiKey: env.GEMINI_API_KEY,
      baseURL: GEMINI_BASE_URL,
    });

    const response = await client.chat.completions.parse({
      model: GEMINI_MODEL,
      max_tokens: 1024,
      response_format: zodResponseFormat(TranslateSchema, "translate_result"),
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: buildUserPrompt(text, context, sourceLanguage) },
      ],
    });

    const message = response.choices?.[0]?.message;

    if (message?.refusal) {
      return { success: false, error: `Model refused: ${message.refusal}` };
    }

    const parsed = message?.parsed;
    if (!parsed?.translated) {
      return { success: false, error: "No translation returned" };
    }

    return { success: true, translated: parsed.translated };
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    console.error("[translate] gemini failed:", msg);
    return { success: false, error: msg };
  }
}
