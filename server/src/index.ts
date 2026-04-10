import { Hono } from "hono";
import type { Bindings } from "./types";
import ocrRoute from "./routes/ocr";

const app = new Hono<{ Bindings: Bindings }>();

app.get("/", (c) => {
  return c.json({ message: "Hello World" });
});

app.route("/api/ocr", ocrRoute);

export default app;
