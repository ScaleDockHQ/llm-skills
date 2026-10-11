# forward_auth against a gateway, and a bearer guard for Ollama

> Verified against Caddy v2.11.7 (docs: forward_auth, reverse_proxy) and Ollama v0.40.3 (server/routes.go); both templates tested locally with Caddy v2.11.7, 2026-10-11

Two patterns that put Caddy in front of an LLM backend without moving key management out of the gateway.

## A. `forward_auth` to LiteLLM (or any OpenAI-compatible gateway)

Use for anything Caddy serves itself that must be limited to valid API-key holders, such as the model catalog (`assets/Caddyfile.catalog`):

```caddy
@models path /v1/models /v1/models/ /models /models/
handle @models {
	forward_auth {$LLM_GATEWAY:127.0.0.1:4000} {
		uri /v1/models
	}
	root * {$LLM_CATALOG_DIR:/var/lib/llm-stack/catalog}
	rewrite * /models.json
	file_server
}
handle {
	reverse_proxy {$LLM_GATEWAY:127.0.0.1:4000} {
		flush_interval -1
	}
}
```

Flow: Caddy sends `GET /v1/models` to the gateway with the client's `Authorization` header. 2xx: Caddy continues and serves the static file. Anything else: the gateway's status and body go back to the client (tested: 401 without key, 200 with key). Completions do not use `forward_auth`: they go straight to the gateway with their own key check.

## B. Bearer guard and Host rewrite for Ollama

Ollama has no auth and returns 403 for a foreign Host header when bound to loopback. `assets/Caddyfile.ollama-guard` listens on `127.0.0.1:8089`, accepts only `Authorization: Bearer {$OLLAMA_PROXY_TOKEN}`, rewrites the upstream Host with `header_up Host {upstream_hostport}`, and streams with `flush_interval -1`. Tested locally: no header gives 401; the right token is proxied.

Hook it up to Tailscale Serve (`tailscale` skill, `references/combos/tailscale-serve-ollama.md`) or to a Cloudflare Tunnel ingress rule (`cloudflare-tunnel` skill) by pointing them at `http://127.0.0.1:8089`.

## Pitfalls

- The matcher compares the whole header value as a string: clients must send exactly `Bearer <token>`.
- Reload does not re-read environment variables: restart after changing the token.
- Single shared token: use LiteLLM for per-client keys.
