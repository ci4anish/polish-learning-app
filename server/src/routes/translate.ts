import { Hono } from "hono";
import type { Bindings, Variables } from "../types";
import { performOcr } from "../services/translate";
import { authMiddleware } from "../middleware/auth";
import { createSupabaseClient } from "../lib/supabase";

const translate = new Hono<{ Bindings: Bindings; Variables: Variables }>();

translate.use(authMiddleware);

translate.post("/", async (c) => {
  const contentType = c.req.header("content-type") ?? "";

  let imageBase64: string;
  let languageHint: string | undefined;

  if (contentType.includes("application/json")) {
    const body = await c.req.json<{ image?: string; languageHint?: string }>();
    if (!body.image) {
      return c.json({ success: false, error: "Missing 'image' field (base64)" }, 400);
    }
    imageBase64 = body.image;
    languageHint = body.languageHint;
  } else if (contentType.includes("multipart/form-data")) {
    const form = await c.req.parseBody();
    const file = form["image"];
    if (!(file instanceof File)) {
      return c.json({ success: false, error: "Missing 'image' file in form data" }, 400);
    }
    const buffer = await file.arrayBuffer();
    const bytes = new Uint8Array(buffer);
    let binary = "";
    for (const byte of bytes) {
      binary += String.fromCharCode(byte);
    }
    const mimeType = file.type || "image/jpeg";
    imageBase64 = `data:${mimeType};base64,${btoa(binary)}`;
    if (typeof form["languageHint"] === "string") {
      languageHint = form["languageHint"];
    }
  } else {
    return c.json(
      { success: false, error: "Content-Type must be application/json or multipart/form-data" },
      415,
    );
  }

  const result = await performOcr(imageBase64, c.env, languageHint);

  const userId = c.get("userId");
  if (userId && result.success && result.content) {
    const supabase = createSupabaseClient(c.env);
    c.executionCtx.waitUntil(
      Promise.resolve(
        supabase.from("ocr_history").insert({
          user_id: userId,
          detected_language: result.content.detectedLanguage,
          blocks: result.content.blocks,
          model: result.model,
          provider: result.provider,
        }),
      ).then(({ error }) => {
        if (error) console.error("[history] failed to save ocr history:", error.message);
      }),
    );
  }

  return c.json(result, result.success ? 200 : 502);
});

export default translate;
