import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import type { Bindings, ExplainResult } from "../types";

const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai/";
const GEMINI_MODEL = "gemini-2.5-flash-lite";

const ExplainSchema = z.object({
  translation: z.string().describe("English translation of the selected text"),
  partOfSpeech: z.string().describe("Part of speech in English with native term in parentheses, e.g. 'Adjective (Przymiotnik)'"),
  gender: z.string().nullable().describe("Grammatical gender if applicable, e.g. 'Masculine', 'Feminine', 'Neuter', or null"),
  grammaticalCase: z.string().nullable().describe("Grammatical case the word appears in within the context, or null"),
  declension: z.array(
    z.object({
      caseName: z.string().describe("Grammatical case name, e.g. 'Nominative', 'Genitive'"),
      singular: z.string().describe("Singular form for this case"),
      plural: z.string().describe("Plural form for this case"),
    }),
  ).nullable().describe("Declension table for nouns/adjectives, conjugation table for verbs, or null if not applicable"),
  examples: z.array(
    z.object({
      polish: z.string().describe("Example sentence in the source language"),
      english: z.string().describe("English translation of the example"),
    }),
  ).describe("2-3 example sentences using the word/phrase"),
});

function buildPrompt(text: string, sourceLanguage: string, context?: string): string {
  const parts = [
    `Explain the following ${sourceLanguage} text for a language learner: "${text}"`,
  ];

  if (context) {
    parts.push(`It appears in this context: "${context}"`);
  }

  parts.push(
    "",
    "Provide:",
    "- Accurate English translation",
    "- Part of speech with the native grammar term",
    "- Gender and grammatical case if applicable",
    "- Full declension or conjugation table if the word is a noun, adjective, or verb",
    "- 2-3 natural example sentences with translations",
  );

  return parts.join("\n");
}

export async function performExplain(
  text: string,
  sourceLanguage: string,
  env: Bindings,
  context?: string,
): Promise<ExplainResult> {
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
      response_format: zodResponseFormat(ExplainSchema, "explanation"),
      messages: [
        {
          role: "user",
          content: buildPrompt(text, sourceLanguage, context),
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

    if (!parsed) {
      return {
        success: false,
        provider: "gemini",
        model: GEMINI_MODEL,
        error: "Failed to parse explanation from model",
      };
    }

    return {
      success: true,
      explanation: {
        selectedText: text,
        translation: parsed.translation,
        partOfSpeech: parsed.partOfSpeech,
        gender: parsed.gender,
        grammaticalCase: parsed.grammaticalCase,
        declension: parsed.declension,
        examples: parsed.examples,
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
    console.error("[explain] gemini failed:", message);
    return {
      success: false,
      provider: "gemini",
      model: GEMINI_MODEL,
      error: message,
    };
  }
}
