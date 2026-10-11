# Qdrant security

> Verified against Qdrant v1.19.2 (docs operations/security, config.yaml), 2026-10-11

- **Auth is off by default** and the service binds `0.0.0.0`. Set `QDRANT__SERVICE__API_KEY` (admin) and optionally `QDRANT__SERVICE__READ_ONLY_API_KEY` (read-only everywhere). Send as header `api-key: <key>`. Docs also accept it as a Bearer token.
- **Granular keys (JWT RBAC).** Set `api_key` plus `jwt_rbac: true` (`QDRANT__SERVICE__JWT_RBAC=true`). Tokens are HS256 JWTs signed with the admin key and can restrict collections and read/write. Changing the admin key invalidates tokens.
- **TLS.** Upstream says enabling an API key requires TLS or an external TLS terminator, otherwise the key travels in clear text. Config: `service.enable_tls: true` with `tls.cert`, `tls.key`, optional `tls.ca_cert` and `verify_https_client_certificate`. Or terminate in Caddy/nginx (`caddy` skill).
- **Cluster port 6335** carries internal traffic that is not authenticated by default. Never expose it. Since v1.18.0 peers attach the admin key; the receiver only enforces it with `service.enforce_internal_auth` / `QDRANT__SERVICE__ENFORCE_INTERNAL_AUTH=true`. Enable it only after all nodes are upgraded. It does not replace network isolation or internal TLS.
- **Network.** Publish `127.0.0.1:6333:6333`; share with other containers over a private Docker network instead of host ports.
- **Telemetry.** `telemetry_disabled` defaults to false; set `QDRANT__TELEMETRY_DISABLED=true` for private deployments.
- **Web UI** is served on the REST port at `/dashboard`; it needs the same key.
- **Key hygiene.** `0600` env file, rotate by restarting with a new key (clients and JWTs must be updated), keep keys out of compose files and shell history.
