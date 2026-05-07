import { Hono } from "hono";
import type { Context } from "hono";
import { stream } from "hono/streaming";
import type { Bindings, Variables } from "../types";
import { performOcr } from "../services/ocr";

type AppContext = Context<{ Bindings: Bindings; Variables: Variables }>;

const ocr = new Hono<{ Bindings: Bindings; Variables: Variables }>();

async function extractImage(c: AppContext): Promise<{ imageBase64: string; languageHint?: string } | null> {
  const contentType = c.req.header("content-type") ?? "";

  if (contentType.includes("application/json")) {
    const body = await c.req.json<{ image?: string; languageHint?: string }>();
    if (!body.image) return null;
    return { imageBase64: body.image, languageHint: body.languageHint };
  }

  if (contentType.includes("multipart/form-data")) {
    const form = await c.req.parseBody();
    const file = form["image"];
    if (!(file instanceof File)) return null;
    const buffer = await file.arrayBuffer();
    const bytes = new Uint8Array(buffer);
    let binary = "";
    for (const byte of bytes) {
      binary += String.fromCharCode(byte);
    }
    const mimeType = file.type || "image/jpeg";
    return {
      imageBase64: `data:${mimeType};base64,${btoa(binary)}`,
      languageHint: typeof form["languageHint"] === "string" ? form["languageHint"] : undefined,
    };
  }

  return null;
}

ocr.post("/", async (c) => {
  const input = await extractImage(c);
  if (!input) {
    return c.json({ success: false, error: "Missing 'image' field" }, 400);
  }

  const result = await performOcr(input.imageBase64, c.env, input.languageHint);
  return c.json(result, result.success ? 200 : 502);
});

ocr.post("/stream", async (c) => {
  const input = await extractImage(c);
  if (!input) {
    return c.json({ success: false, error: "Missing 'image' field" }, 400);
  }

  const env = c.env;
  const encoder = new TextEncoder();

  c.header("Content-Type", "text/plain; charset=utf-8");
  c.header("X-Content-Type-Options", "nosniff");

  return stream(c, async (s) => {
    const result = await performOcr(input.imageBase64, env, input.languageHint);

    if (!result.success || !result.content) {
      await s.write(encoder.encode(JSON.stringify({ event: "error", error: result.error ?? "OCR failed" }) + "\n"));
      return;
    }

    const { detectedLanguage, blocks } = result.content;

    await s.write(encoder.encode(JSON.stringify({ event: "meta", detectedLanguage }) + "\n"));

    for (const block of blocks) {
      await s.write(encoder.encode(JSON.stringify({ event: "block", block }) + "\n"));
    }

    await s.write(encoder.encode(JSON.stringify({ event: "done" }) + "\n"));
  });
});

export default ocr;
