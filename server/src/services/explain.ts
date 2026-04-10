import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import type { Bindings, ExplainResult } from "../types";

const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai/";
const GEMINI_MODEL = "gemini-2.5-flash-lite";

function buildSchema(targetLanguage: string) {
  return z.object({
    translation: z.string().describe(`Translation of the selected text into ${targetLanguage}`),
    partOfSpeech: z.string().describe(`Part of speech in ${targetLanguage} with the native grammar term in parentheses, e.g. 'Прикметник (Przymiotnik)'`),
    gender: z.string().nullable().describe(`Grammatical gender in ${targetLanguage} if applicable, e.g. 'Чоловічий', 'Жіночий', 'Середній', or null`),
    grammaticalCase: z.string().nullable().describe(`Grammatical case the word appears in within the context, in ${targetLanguage}, or null`),
    declension: z.array(
      z.object({
        caseName: z.string().describe(`Grammatical case name in ${targetLanguage}, e.g. 'Називний', 'Родовий'`),
        singular: z.string().describe("Singular form for this case"),
        plural: z.string().describe("Plural form for this case"),
      }),
    ).nullable().describe("Declension table for nouns/adjectives, conjugation table for verbs, or null if not applicable"),
    examples: z.array(
      z.object({
        source: z.string().describe("Example sentence in the source language"),
        target: z.string().describe(`Translation of the example into ${targetLanguage}`),
      }),
    ).describe("2-3 example sentences using the word/phrase"),
  });
}

function buildPrompt(text: string, sourceLanguage: string, targetLanguage: string, context?: string): string {
  const parts = [
    `Explain the following ${sourceLanguage} text for a language learner: "${text}"`,
  ];

  if (context) {
    parts.push(`It appears in this context: "${context}"`);
  }

  parts.push(
    "",
    `Provide all explanations in ${targetLanguage}:`,
    `- Accurate translation into ${targetLanguage}`,
    "- Part of speech with the native grammar term in parentheses",
    `- Gender and grammatical case in ${targetLanguage} if applicable`,
    "- Full declension or conjugation table if the word is a noun, adjective, or verb",
    `- 2-3 natural example sentences with ${targetLanguage} translations`,
  );

  return parts.join("\n");
}

export async function performExplain(
  text: string,
  sourceLanguage: string,
  targetLanguage: string,
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
      response_format: zodResponseFormat(buildSchema(targetLanguage), "explanation"),
      messages: [
        {
          role: "user",
          content: buildPrompt(text, sourceLanguage, targetLanguage, context),
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
        examples: parsed.examples.map((e) => ({ source: e.source, target: e.target })),
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
