---
persona: staff-engineer
findings:
- target: src/auth/session.ts:11
  claim: Session lifetime jumps 24x with no security boundary besides the token itself — a product request is not an auth policy decision, and this diff ships no compensating control (refresh token, re-auth,
    activity timeout).
  evidence: 'expiresAt: now + 24 * 3600_000, // bumped from 1h to 24h per product request

    '
  ask: Either cite the auth policy that permits a 24h bare session, or pair this bump with a short-lived access token + refresh flow so a stolen token isn't valid for a full day.
  severity: major
  category: correctness
  id: staff-engineer-be9bd4f1
- target: src/auth/session.ts:17-19
  claim: The in-memory sessions map grows unbounded — expired sessions are only cleaned up on access. With 24h lifetimes and no reaper, abandoned sessions leak until the process restarts.
  evidence: 'if (s.expiresAt < Date.now()) { sessions.delete(token); return null; }

    '
  ask: Add a periodic sweep or LRU eviction that caps the map size, or switch to an external store that handles TTL natively.
  severity: minor
  category: complexity
  id: staff-engineer-fc20487e
dropped_findings: []
---

## Summary

The real issue is the 24x lifetime increase with no accompanying security mechanism. A bare 24h session token — no refresh rotation, no activity timeout, no re-auth gate — means a leaked token is valid for an entire workday. The inline expiry-check addition is fine mechanically but introduces a lazy-delete pattern that doesn't bound memory.
