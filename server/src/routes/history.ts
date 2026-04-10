import { Hono } from "hono";
import type { Bindings, Variables } from "../types";
import { authMiddleware } from "../middleware/auth";
import { createSupabaseClient } from "../lib/supabase";

const history = new Hono<{ Bindings: Bindings; Variables: Variables }>();

history.use(authMiddleware);

history.get("/ocr", async (c) => {
  const userId = c.get("userId");
  if (!userId) {
    return c.json({ success: false, error: "Unauthorized" }, 401);
  }

  const supabase = createSupabaseClient(c.env);
  const { data, error } = await supabase
    .from("ocr_history")
    .select("id, detected_language, blocks, model, provider, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(50);

  if (error) {
    return c.json({ success: false, error: error.message }, 500);
  }

  return c.json({ success: true, data });
});

export default history;
