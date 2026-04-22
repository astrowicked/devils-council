--- a/src/auth/session.ts
+++ b/src/auth/session.ts
@@ -10,7 +10,12 @@ export function createSession(userId: string): Session {
   const token = randomBytes(32).toString("hex");
   const now = Date.now();
-  return { userId, token, createdAt: now, expiresAt: now + 3600_000 };
+  return {
+    userId,
+    token,
+    createdAt: now,
+    expiresAt: now + 24 * 3600_000, // bumped from 1h to 24h per product request
+  };
 }

 export function validateSession(token: string): Session | null {
-  return sessions.get(token) ?? null;
+  const s = sessions.get(token);
+  if (!s) return null;
+  if (s.expiresAt < Date.now()) { sessions.delete(token); return null; }
+  return s;
 }
