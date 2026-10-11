# Weaviate security

> Verified against Weaviate v1.40.0 (docs deploy/configuration/authentication, configuring-rbac, installation guide), 2026-10-11

- **Anonymous access** is enabled in upstream's quick-start examples (`AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'`). Set it to `'false'` for any shared or networked instance.
- **API keys.** `AUTHENTICATION_APIKEY_ENABLED=true`, `AUTHENTICATION_APIKEY_ALLOWED_KEYS=key-a,key-b`, `AUTHENTICATION_APIKEY_USERS=user-a,user-b` (one user per key, same order, or a single user for all keys). Clients send `Authorization: Bearer <key>`. Keys live in the `0600` env file; rotate by editing and restarting.
- **RBAC.** `AUTHORIZATION_RBAC_ENABLED=true` and `AUTHORIZATION_RBAC_ROOT_USERS=<user>` (the root user must exist in the auth config; on versions 1.30.6 and 1.31.0 and older Weaviate will not start otherwise). Define least-privilege roles for applications; do not give apps the root user. OIDC can be combined with RBAC.
- **Ports.** Publish `127.0.0.1:8080:8080` and `127.0.0.1:50051:50051`, or use a private Docker network. Port 2112 (Prometheus) is internal. If you publish through a proxy, upstream notes HTTP and gRPC (h2c) need separate routes.
- **TLS.** Weaviate does not terminate TLS in the quick start; use a reverse proxy (`caddy`) or private network.
- **Vectorizer keys.** `OPENAI_APIKEY` (or request header `X-OpenAI-Api-Key`) is the key for your embeddings endpoint; if that is LiteLLM, use a scoped virtual key. Never log it.
- **Backups** (filesystem or cloud) contain your data; protect them like the source.
