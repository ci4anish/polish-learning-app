import { Hono } from "hono";
import type { Bindings, Variables } from "../types";
import { performExplain } from "../services/explain";
import { authMiddleware } from "../middleware/auth";
import { createSupabaseClient } from "../lib/supabase";

const explain = new Hono<{ Bindings: Bindings; Variables: Variables }>();

explain.use(authMiddleware);

explain.post("/", async (c) => {
  const body = await c.req.json<{
    text?: string;
    sourceLanguage?: string;
    targetLanguage?: string;
    context?: string;
  }>();

  if (!body.text) {
    return c.json({ success: false, error: "Missing 'text' field" }, 400);
  }

  const sourceLanguage = body.sourceLanguage ?? "Polish";
  const targetLanguage = body.targetLanguage ?? "Ukrainian";
  const result = await performExplain(body.text, sourceLanguage, targetLanguage, c.env, body.context);

  const userId = c.get("userId");
  if (userId && result.success && result.explanation) {
    const supabase = createSupabaseClient(c.env);
    c.executionCtx.waitUntil(
      Promise.resolve(
        supabase.from("explain_history").insert({
          user_id: userId,
          selected_text: result.explanation.selectedText,
          source_language: sourceLanguage,
          target_language: targetLanguage,
          translation: result.explanation.translation,
          explanation: result.explanation,
          model: result.model,
          provider: result.provider,
        }),
      ).then(({ error }) => {
        if (error) console.error("[history] failed to save explain history:", error.message);
      }),
    );
  }

  return c.json(result, result.success ? 200 : 502);
});

export default explain;
