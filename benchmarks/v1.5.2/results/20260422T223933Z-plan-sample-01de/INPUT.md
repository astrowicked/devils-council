# Plan: Add request-rate limiter to public API

## Goal
Protect the `/api/v1/search` endpoint from abusive clients by rate-limiting
per-IP to 60 requests/min.

## Approach
- Add an in-memory token-bucket keyed on `req.ip`.
- Bucket size 60, refill 1 token/second.
- On exhaustion, return HTTP 429 with a `Retry-After: 1` header.
- Feature-flag via `RATE_LIMIT_ENABLED=true`.

## Rollout
Ship behind the flag. Flip on in staging for 24h. Flip on in prod next week.

## Risks
- In-memory state does not survive restart; limits reset on deploy.
- Single-node deployment today; no shared counter across replicas (we run one).
- IP-based keying hits NAT'd corporate clients disproportionately.
