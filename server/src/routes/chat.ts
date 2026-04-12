import { Hono } from "hono";
import { stream } from "hono/streaming";
import type { Bindings, Variables, ChatMessage } from "../types";
import { authMiddleware } from "../middleware/auth";
import { createSupabaseClient } from "../lib/supabase";
import { createChatStream } from "../services/chat";

const chat = new Hono<{ Bindings: Bindings; Variables: Variables }>();

chat.use(authMiddleware);

chat.post("/start", async (c) => {
  const authHeader = c.req.header("Authorization");
  console.log("[chat/start] auth header present:", !!authHeader);
  const userId = c.get("userId");
  console.log("[chat/start] userId:", userId);
  if (!userId) {
    return c.json({ success: false, error: "Authentication required" }, 401);
  }

  const body = await c.req.json<{
    text?: string;
    context?: string;
    sourceLanguage?: string;
  }>();

  if (!body.text) {
    return c.json({ success: false, error: "Missing 'text' field" }, 400);
  }

  const supabase = createSupabaseClient(c.env);

  const { data, error } = await supabase
    .from("chat_threads")
    .insert({
      user_id: userId,
      selected_text: body.text,
      context_block: body.context ?? null,
      source_language: body.sourceLanguage ?? null,
    })
    .select("id")
    .single();

  if (error || !data) {
    console.error("[chat] failed to create thread:", error?.message);
    return c.json({ success: false, error: "Failed to create chat thread" }, 500);
  }

  return c.json({ success: true, threadId: data.id });
});

chat.post("/message", async (c) => {
  const userId = c.get("userId");
  if (!userId) {
    return c.json({ success: false, error: "Authentication required" }, 401);
  }

  const body = await c.req.json<{
    threadId?: string;
    message?: string;
  }>();

  if (!body.threadId || !body.message) {
    return c.json({ success: false, error: "Missing 'threadId' or 'message'" }, 400);
  }

  const supabase = createSupabaseClient(c.env);

  const { data: thread, error: threadErr } = await supabase
    .from("chat_threads")
    .select("id, selected_text, context_block, source_language")
    .eq("id", body.threadId)
    .eq("user_id", userId)
    .single();

  if (threadErr || !thread) {
    return c.json({ success: false, error: "Thread not found" }, 404);
  }

  await supabase.from("chat_messages").insert({
    thread_id: body.threadId,
    role: "user",
    content: body.message,
  });

  const { data: history } = await supabase
    .from("chat_messages")
    .select("role, content")
    .eq("thread_id", body.threadId)
    .order("created_at", { ascending: true })
    .limit(10);

  const messages: ChatMessage[] = (history ?? []).map((m) => ({
    role: m.role as "user" | "assistant",
    content: m.content as string,
  }));

  const env = c.env;

  c.header("Content-Type", "text/plain; charset=utf-8");
  c.header("X-Content-Type-Options", "nosniff");

  return stream(c, async (s) => {
    let fullResponse = "";
    try {
      const completion = await createChatStream(
        messages,
        thread.selected_text,
        env,
        thread.context_block ?? undefined,
        thread.source_language ?? undefined,
      );

      const encoder = new TextEncoder();

      for await (const chunk of completion) {
        const content = chunk.choices?.[0]?.delta?.content;
        if (content) {
          fullResponse += content;
          await s.write(encoder.encode(content));
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      console.error("[chat] streaming failed:", msg);
    }

    if (fullResponse) {
      const { error: saveErr } = await supabase.from("chat_messages").insert({
        thread_id: body.threadId,
        role: "assistant",
        content: fullResponse,
      });
      if (saveErr) {
        console.error("[chat] failed to save assistant message:", saveErr.message);
      }
    }
  });
});

export default chat;
