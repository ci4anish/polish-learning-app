import { Hono } from "hono";
import type { Bindings, Variables } from "./types";
import ocrRoute from "./routes/ocr";
import historyRoute from "./routes/history";
import audioRoute from "./routes/audio";
import translateRoute from "./routes/translate";
import chatRoute from "./routes/chat";

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

app.get("/", (c) => {
  return c.json({ message: "Hello World" });
});

app.get("/api/health/supabase", async (c) => {
  const { createSupabaseClient } = await import("./lib/supabase");
  const supabase = createSupabaseClient(c.env);
  const { error } = await supabase.from("ocr_history").select("id").limit(1);
  if (error) {
    return c.json({ connected: false, error: error.message }, 500);
  }
  return c.json({ connected: true });
});

app.route("/api/ocr", ocrRoute);
app.route("/api/history", historyRoute);
app.route("/api/audio", audioRoute);
app.route("/api/translate", translateRoute);
app.route("/api/chat", chatRoute);

export default app;
