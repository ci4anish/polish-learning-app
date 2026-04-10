import { Hono } from "hono";
import type { Bindings } from "./types";
import ocrRoute from "./routes/ocr";
import explainRoute from "./routes/explain";

const app = new Hono<{ Bindings: Bindings }>();

app.get("/", (c) => {
  return c.json({ message: "Hello World" });
});

app.route("/api/ocr", ocrRoute);
app.route("/api/explain", explainRoute);

export default app;
