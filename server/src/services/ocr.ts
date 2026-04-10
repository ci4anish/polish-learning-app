import OpenAI from "openai";
import type { Bindings, OcrResult } from "../types";

type ProviderConfig = {
  name: string;
  baseURL: string;
  model: string;
  apiKeyField: keyof Pick<Bindings, "DEEPINFRA_API_KEY" | "NOVITA_API_KEY">;
};

const PROVIDERS: Record<string, ProviderConfig> = {
  deepinfra: {
    name: "deepinfra",
    baseURL: "https://api.deepinfra.com/v1/openai",
    model: "deepseek-ai/DeepSeek-OCR",
    apiKeyField: "DEEPINFRA_API_KEY",
  },
  novita: {
    name: "novita",
    baseURL: "https://api.novita.ai/openai",
    model: "deepseek/deepseek-ocr",
    apiKeyField: "NOVITA_API_KEY",
  },
};

const DEFAULT_ORDER = ["deepinfra", "novita"];

function getProviderOrder(env: Bindings): string[] {
  if (!env.PROVIDER_ORDER) return DEFAULT_ORDER;

  const order = env.PROVIDER_ORDER.split(",")
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s in PROVIDERS);

  return order.length > 0 ? order : DEFAULT_ORDER;
}

function ensureDataUrl(base64Image: string): string {
  if (base64Image.startsWith("data:")) return base64Image;
  return `data:image/jpeg;base64,${base64Image}`;
}

export async function performOcr(
  imageBase64: string,
  env: Bindings,
): Promise<OcrResult> {
  const providerOrder = getProviderOrder(env);
  const errors: string[] = [];

  for (const providerKey of providerOrder) {
    const provider = PROVIDERS[providerKey];
    const apiKey = env[provider.apiKeyField];

    if (!apiKey) {
      errors.push(`${provider.name}: API key not configured`);
      continue;
    }

    try {
      const client = new OpenAI({
        apiKey,
        baseURL: provider.baseURL,
      });

      const response = await client.chat.completions.create({
        model: provider.model,
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
                text: "<|grounding|>OCR this image.",
              },
            ],
          },
        ],
      });

      const text = response.choices?.[0]?.message?.content ?? "";

      return {
        success: true,
        text,
        provider: provider.name,
        model: provider.model,
        usage: response.usage
          ? {
              prompt_tokens: response.usage.prompt_tokens,
              completion_tokens: response.usage.completion_tokens,
              total_tokens: response.usage.total_tokens,
            }
          : undefined,
      };
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Unknown error";
      errors.push(`${provider.name}: ${message}`);
      console.error(`[ocr] ${provider.name} failed:`, message);
    }
  }

  return {
    success: false,
    text: "",
    provider: "",
    model: "",
    error: `All providers failed: ${errors.join("; ")}`,
  };
}
