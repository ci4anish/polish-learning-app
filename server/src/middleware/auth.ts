import { createMiddleware } from "hono/factory";
import { createRemoteJWKSet, jwtVerify } from "jose";
import type { Bindings, Variables } from "../types";

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null;

function getJWKS(supabaseUrl: string) {
  if (!jwks) {
    jwks = createRemoteJWKSet(
      new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`),
    );
  }
  return jwks;
}

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
      const keySet = getJWKS(c.env.SUPABASE_URL);
      const { payload } = await jwtVerify(token, keySet);
      if (payload.sub) {
        c.set("userId", payload.sub);
      }
    } catch {
      // Invalid or expired token — proceed unauthenticated
    }
  }

  await next();
});
