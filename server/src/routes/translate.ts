import { Hono } from "hono";
import type { Bindings, Variables } from "../types";
import { performTranslation } from "../services/translate";
import { authMiddleware } from "../middleware/auth";

const translate = new Hono<{ Bindings: Bindings; Variables: Variables }>();

translate.use(authMiddleware);

translate.post("/", async (c) => {
  const body = await c.req.json<{
    text?: string;
    context?: string;
    sourceLanguage?: string;
  }>();

  if (!body.text) {
    return c.json({ success: false, error: "Missing 'text' field" }, 400);
  }

  const result = await performTranslation(
    body.text,
    c.env,
    body.context,
    body.sourceLanguage,
  );

  return c.json(result, result.success ? 200 : 502);
});

export default translate;
