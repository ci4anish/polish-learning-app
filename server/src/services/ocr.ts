import OpenAI from "openai";
import type { Bindings, OcrResult } from "../types";

const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai/";
const GEMINI_MODEL = "gemini-2.5-flash-lite";

function ensureDataUrl(base64Image: string): string {
  if (base64Image.startsWith("data:")) return base64Image;
  return `data:image/jpeg;base64,${base64Image}`;
}

export async function performOcr(
  imageBase64: string,
  env: Bindings,
): Promise<OcrResult> {
  if (!env.GEMINI_API_KEY) {
    return {
      success: false,
      text: "",
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

    const response = await client.chat.completions.create({
      model: GEMINI_MODEL,
      max_tokens: 4096,
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
              text: "Extract all text from this image. Return only the extracted text, preserving the original language and layout. Do not translate or summarize.",
            },
          ],
        },
      ],
    });

    const text = response.choices?.[0]?.message?.content ?? "";

    return {
      success: true,
      text,
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
      text: "",
      provider: "gemini",
      model: GEMINI_MODEL,
      error: message,
    };
  }
}
