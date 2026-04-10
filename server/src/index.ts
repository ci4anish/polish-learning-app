import { Hono } from "hono";
import type { Bindings, Variables } from "./types";
import ocrRoute from "./routes/ocr";
import explainRoute from "./routes/explain";
import historyRoute from "./routes/history";
import audioRoute from "./routes/audio";

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

app.get("/", (c) => {
  return c.json({ message: "Hello World" });
});

app.route("/api/ocr", ocrRoute);
app.route("/api/explain", explainRoute);
app.route("/api/history", historyRoute);
app.route("/api/audio", audioRoute);

export default app;
