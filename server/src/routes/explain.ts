import { Hono } from "hono";
import type { Bindings } from "../types";
import { performExplain } from "../services/explain";

const explain = new Hono<{ Bindings: Bindings }>();

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

  return c.json(result, result.success ? 200 : 502);
});

export default explain;
