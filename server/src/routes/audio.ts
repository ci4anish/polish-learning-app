import { Hono } from "hono";
import type { Bindings, Variables } from "../types";
import { performTTS } from "../services/audio";
import { authMiddleware } from "../middleware/auth";

const audio = new Hono<{ Bindings: Bindings; Variables: Variables }>();

audio.use(authMiddleware);

audio.post("/", async (c) => {
  const body = await c.req.json<{ text?: string; language?: string }>();

  if (!body.text) {
    return c.json({ success: false, error: "Missing 'text' field" }, 400);
  }

  const result = await performTTS(body.text, c.env, body.language);

  if (!result.success || !result.audioData) {
    return c.json({ success: false, error: result.error ?? "TTS failed" }, 502);
  }

  const wav = new Uint8Array(result.audioData.buffer as ArrayBuffer, result.audioData.byteOffset, result.audioData.byteLength);

  return c.body(wav, 200, {
    "Content-Type": result.mimeType ?? "audio/wav",
    "Content-Length": wav.length.toString(),
  });
});

export default audio;
