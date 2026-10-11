# Traefik: middlewares for LLM endpoints

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: reference "HTTP Middlewares": forwardAuth, basicAuth, ipAllowList, rateLimit, retry, buffering, compress, headers.

Attach with `middlewares: [a, b]` on a router; order matters.

## Authentication

- **basicAuth:** `users: ["name:<hash>"]` or `usersFile` (lines `name:hashed-password`). Generate hashes with `htpasswd -nbB`; keep the file `0600`. Fine for people, awkward for SDKs that expect `Authorization: Bearer`.
- **forwardAuth:** Traefik asks an external service; a 2XX allows the request, anything else is returned to the client. Options: `address`, `trustForwardHeader`, `authResponseHeaders`, `authRequestHeaders`, `maxBodySize`, `forwardBody`. **Do not set `forwardBody: true` on LLM routes**: the body is read inside Traefik and upstream says this breaks streaming. A forwardAuth service can validate bearer keys; run LiteLLM or an auth proxy for budgets.
- **apiKey, jwt, oidc, oauth2 introspection, hmac** exist as middlewares in the v3.7 reference; check each page's edition and requirements before use.

```yaml
http:
  middlewares:
    llm-auth:
      forwardAuth:
        address: "http://auth:9000/verify"
        authRequestHeaders: ["Authorization"]
        authResponseHeaders: ["X-User"]
```

## Network and rate controls

- **ipAllowList:** `sourceRange: ["10.0.0.0/8", "100.64.0.0/10"]`. Behind another proxy set `ipStrategy.depth` or `excludedIPs` so the right client IP from `X-Forwarded-For` is used.
- **rateLimit:** `average` (0 = no limiting), `period` (1s), `burst` (1), `sourceCriterion`. It counts requests, not tokens; budgets belong in LiteLLM.
- **retry:** `attempts`, `initialInterval`. Do not retry non-idempotent streaming completions blindly.
- **inFlightReq** limits concurrent requests per source.

## Avoid on streaming routes

- **buffering:** reads the whole request before forwarding (memory or disk) and sets a fixed `Content-Length`; fine for upload limits, harmful for large streaming bodies.
- **compress:** do not compress `text/event-stream`; use `excludedContentTypes`.

## Headers

`headers` middleware sets CORS and security headers; for browser clients add `accessControlAllowOriginList` and allowed headers including `Authorization`.
