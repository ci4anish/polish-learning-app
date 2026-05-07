import { Hono } from "hono";
import { stream } from "hono/streaming";
import type { Bindings, Variables, ChatMessage } from "../types";
import { createChatStream } from "../services/chat";

const chat = new Hono<{ Bindings: Bindings; Variables: Variables }>();

type ChatRequest = {
  text?: string;
  context?: string;
  sourceLanguage?: string;
  messages?: ChatMessage[];
};

function sanitizeMessages(input: ChatMessage[] | undefined): ChatMessage[] {
  if (!Array.isArray(input)) return [];
  return input
    .filter((m): m is ChatMessage =>
      !!m &&
      (m.role === "user" || m.role === "assistant") &&
      typeof m.content === "string",
    )
    .map((m) => ({ role: m.role, content: m.content }));
}

chat.post("/", async (c) => {
  const body = await c.req.json<ChatRequest>();

  if (!body.text) {
    return c.json({ success: false, error: "Missing 'text' field" }, 400);
  }

  const messages = sanitizeMessages(body.messages);
  const env = c.env;

  c.header("Content-Type", "text/plain; charset=utf-8");
  c.header("X-Content-Type-Options", "nosniff");

  return stream(c, async (s) => {
    try {
      const completion = await createChatStream(
        messages,
        body.text!,
        env,
        body.context,
        body.sourceLanguage,
      );

      const encoder = new TextEncoder();

      for await (const chunk of completion) {
        const content = chunk.choices?.[0]?.delta?.content;
        if (content) {
          await s.write(encoder.encode(content));
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      console.error("[chat] streaming failed:", msg);
    }
  });
});

export default chat;
