# Plan: Rotate TLS certs on edge load balancers

## Goal
Rotate the TLS certificates terminating on the public edge load balancers
ahead of the current cert expiry window. Avoid user-visible downtime.

## Approach
- Pre-provision the new cert via the internal ACME endpoint.
- Stage the cert bundle onto each load balancer's cert store.
- Hot-reload nginx on each node in sequence behind the health check.
- Leave the previous cert in place for 24h to support client retries.

## Rollout
Enable on canary LB first, verify TLS handshake metrics, then roll through
the remaining LBs one at a time with a 15-minute soak between each.

## Risks
- HSTS-pinned clients on the old cert chain hit handshake failures.
- Incomplete hot-reload leaves a node serving the old cert indefinitely.
- Cert store permissions regression blocks nginx startup on reload.
