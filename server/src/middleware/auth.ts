import { createMiddleware } from "hono/factory";
import { jwtVerify } from "jose";
import type { Bindings, Variables } from "../types";

/**
 * Optional auth middleware — sets `userId` in context if a valid Supabase JWT
 * is present. Routes proceed regardless; they decide whether to require auth.
 */
export const authMiddleware = createMiddleware<{
  Bindings: Bindings;
  Variables: Variables;
}>(async (c, next) => {
  const authHeader = c.req.header("Authorization");

  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.slice(7);
    try {
      const secret = new TextEncoder().encode(c.env.SUPABASE_JWT_SECRET);
      const { payload } = await jwtVerify(token, secret);
      if (payload.sub) {
        c.set("userId", payload.sub);
      }
    } catch {
      // Invalid or expired token — proceed unauthenticated
    }
  }

  await next();
});
