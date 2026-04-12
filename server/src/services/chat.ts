import OpenAI from "openai";
import type { Bindings, ChatMessage } from "../types";
import { GEMINI_BASE_URL, GEMINI_MODEL } from "../lib/constants";

const SYSTEM_PROMPT = [
  "You are a friendly Polish language tutor for Ukrainian-speaking students.",
  "The student is reading a Polish text and selected a word or phrase they want to understand.",
  "Focus on Polish-specific grammar: cases (przypadki), verb conjugations, aspect, prepositions, and how they differ from Ukrainian.",
  "Use Markdown formatting: bold for key terms, tables for declensions/conjugations when helpful.",
  "Keep explanations short and practical. Use examples from the provided context when possible.",
  "Highlight similarities and differences between Polish and Ukrainian to help the student learn faster.",
  "Always respond in Ukrainian (Cyrillic). Write Polish examples in Latin script.",
].join(" ");

function buildInitialUserPrompt(
  text: string,
  context?: string,
  sourceLanguage?: string,
): string {
  const parts: string[] = [];
  if (sourceLanguage) parts.push(`Мова тексту: ${sourceLanguage}`);
  if (context && context !== text) parts.push(`Контекст: «${context}»`);
  parts.push(`Виділений текст: «${text}»`);
  parts.push("Привітай мене одним реченням. Дай короткий огляд граматики (2-3 речення максимум). Запитай, що саме цікавить — відмінювання, вживання чи щось інше.");
  return parts.join("\n");
}

export function createChatStream(
  messages: ChatMessage[],
  selectedText: string,
  env: Bindings,
  context?: string,
  sourceLanguage?: string,
) {
  if (!env.GEMINI_API_KEY) {
    throw new Error("GEMINI_API_KEY is not configured");
  }

  const client = new OpenAI({
    apiKey: env.GEMINI_API_KEY,
    baseURL: GEMINI_BASE_URL,
  });

  const isFirstMessage = messages.length <= 1;

  const openaiMessages: OpenAI.ChatCompletionMessageParam[] = [
    { role: "system", content: SYSTEM_PROMPT },
  ];

  if (isFirstMessage) {
    openaiMessages.push({
      role: "user",
      content: buildInitialUserPrompt(selectedText, context, sourceLanguage),
    });
  } else {
    openaiMessages.push(
      ...messages.map((m) => ({
        role: m.role as "user" | "assistant",
        content: m.content,
      })),
    );
  }

  return client.chat.completions.create({
    model: GEMINI_MODEL,
    max_tokens: 512,
    stream: true,
    messages: openaiMessages,
  });
}
