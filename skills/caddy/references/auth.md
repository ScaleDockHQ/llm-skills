# Auth patterns in front of LLM endpoints

> Verified against Caddy v2.11.7 (docs: forward_auth, basic_auth, request_body; behaviour tested locally with Caddy v2.11.7 on 2026-10-11), 2026-10-11

Rule of thumb: the **gateway** (LiteLLM) owns API keys. Caddy adds a check only where the backend has none, or to avoid duplicating key logic.

| Pattern                           | Use when                                                                                    | Config                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `forward_auth` to the gateway     | serving something static or different (model catalog) only to valid gateway keys            | `forward_auth <gateway> { uri /v1/models }`          |
| Shared bearer token               | engine without auth (Ollama, llama.cpp) behind a tunnel or Serve; one token for all callers | header matcher, `assets/Caddyfile.ollama-guard`      |
| `basic_auth`                      | a dashboard in a browser                                                                    | `basic_auth { <user> <hash> }`                       |
| Identity from Tailscale Serve     | tailnet users only                                                                          | `Tailscale-User-Login` header, loopback backend only |
| Edge identity (Cloudflare Access) | dashboards                                                                                  | `cloudflare-tunnel` skill                            |

## `forward_auth`

Makes a `GET` to the auth upstream with the URI rewritten (`uri`). A `2xx` response lets handling continue and copies any `copy_headers` fields onto the original request. Any other response is copied back to the client. The request body is not consumed (the check is always `GET`). All `reverse_proxy` subdirectives work inside the block.

```caddy
handle @models {
	forward_auth 127.0.0.1:4000 {
		uri /v1/models        # any endpoint every valid key may call, and cheap
	}
	root * /var/lib/llm-stack/catalog
	rewrite * /models.json
	file_server
}
```

Tested locally on v2.11.7: without a key the gateway's 401 body reaches the client; with a key the static file is served (200). The `Authorization` header from the client is forwarded to the auth upstream by default, which is what makes this work with LiteLLM.

Pitfalls: pick a check URI that any valid key may call (a path restricted by key or role gives false 403s); the check adds one internal round trip, so do not put it in front of streaming completions, let the gateway authenticate those directly.

## Bearer matcher for engines without auth

```caddy
:8089 {
	bind 127.0.0.1
	@ok header Authorization "Bearer {$OLLAMA_PROXY_TOKEN}"
	handle @ok {
		reverse_proxy 127.0.0.1:11434 {
			header_up Host {upstream_hostport}
			flush_interval -1
		}
	}
	handle { respond "unauthorized" 401 }
}
```

Tested locally: no header gives 401, correct token reaches the upstream. Generate the token with `openssl rand -hex 32` straight into a `0600` env file; never type it into a shared shell. This is one shared secret and not constant-time compared by a documented guarantee (unverified): treat it as a fence, not as multi-user auth; for several clients put LiteLLM in between.

## `basic_auth` (dashboards)

Passwords must be hashed: run `caddy hash-password` and paste the hash. Default algorithm is bcrypt, `argon2id` is also available.

```caddy
dash.example.com {
	basic_auth {
		alice {$DASH_ALICE_HASH}
	}
	reverse_proxy 127.0.0.1:5555
}
```

Browsers prompt; API clients do not use this. Prefer Access or Tailscale identity for dashboards you share.

## Tailscale identity headers

Behind `tailscale serve`, the daemon adds `Tailscale-User-Login`, `Tailscale-User-Name` and `Tailscale-User-Profile-Pic` for tailnet users (not for tagged devices, not for Funnel) and removes spoofed copies. Caddy can allow by login, for example `@alice header Tailscale-User-Login alice@example.com`. Trust it only if Caddy listens on `127.0.0.1`, otherwise anyone who can reach the port sets the header. Caddy's own docs show a `forward_auth` example against Tailscale's `nginx-auth` helper (`tailscale.nginx-auth.sock`); that helper is a separate Tailscale tool, not verified further here.

## What not to do

- Do not put API keys, hashes or tokens into a Caddyfile that lives in git: use `{$VAR}`.
- Do not enable `log_credentials`; `Authorization`, `Cookie`, `Set-Cookie` and `Proxy-Authorization` are redacted in access logs by default.
- Do not expose the admin endpoint.

## Official links

- [forward_auth](https://caddyserver.com/docs/caddyfile/directives/forward_auth)
- [basic_auth](https://caddyserver.com/docs/caddyfile/directives/basic_auth)
- [Request matchers: header](https://caddyserver.com/docs/caddyfile/matchers)
- [Tailscale Serve identity headers](https://tailscale.com/kb/1312)
