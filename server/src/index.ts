import { Hono } from "hono";
import type { Bindings, Variables } from "./types";
import ocrRoute from "./routes/ocr";
import audioRoute from "./routes/audio";
import translateRoute from "./routes/translate";
import chatRoute from "./routes/chat";

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

app.get("/", (c) => {
  return c.json({ message: "Hello World" });
});

app.route("/api/ocr", ocrRoute);
app.route("/api/audio", audioRoute);
app.route("/api/translate", translateRoute);
app.route("/api/chat", chatRoute);

export default app;
