---
persona: sre
findings:
- target: export function createSession
  claim: 24x TTL increase with an in-memory Map and no background reaper turns every session into a 24-hour memory reservation. At 1h TTL, peak memory was bounded by one hour's concurrent users; at 24h,
    it's bounded by an entire day's cumulative logins. The process will OOM and restart — losing all sessions.
  evidence: 'expiresAt: now + 24 * 3600_000, // bumped from 1h to 24h per product request

    '
  ask: At your login rate × session-object size × 24h retention, does the process fit in its container memory limit? If sessions is a plain Map with no LRU eviction and no interval-based sweep, give me
    the OOM timeline at peak traffic.
  severity: major
  category: blast-radius
  id: sre-c362da8a
- target: src/auth/session.ts:17-19
  claim: There is no revocation path. If a token is compromised, there is no invalidateSession or invalidateAllSessions(userId) — the only way to kill a token is to restart the process (losing all sessions)
    or wait 24 hours for it to expire naturally.
  evidence: 'if (s.expiresAt < Date.now()) { sessions.delete(token); return null; }

    '
  ask: What is the incident response when a token leak is detected? With no revocation mechanism and a 24h window, the answer today is 'wait 24 hours or restart the world.' Define a kill switch.
  severity: major
  category: blast-radius
  id: sre-95478d9d
dropped_findings: []
---

## Summary

The operational story breaks at the intersection of 24h session lifetime and in-memory storage with no reaper and no revocation. A compromise means 24 hours of exposure with no kill switch. A traffic spike means unbounded memory growth with no eviction. The expiry check is correct but insufficient — it's cleanup-on-access, not cleanup-on-schedule.
