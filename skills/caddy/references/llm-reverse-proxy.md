# Reverse proxy for LLM endpoints

> Verified against Caddy v2.11.7 (docs: reverse_proxy, global options, request_body, header; source modules/caddyhttp at v2.11.7), 2026-10-11

Templates: `assets/Caddyfile.llm-edge` (public or LAN TLS edge), `assets/Caddyfile.catalog` (loopback front behind a tunnel or Serve), `assets/Caddyfile.ollama-guard`.

## Minimal and streaming-safe

```caddy
llm.example.com {
	reverse_proxy 127.0.0.1:4000 {
		flush_interval -1
	}
}
```

## Streaming (SSE and NDJSON)

- By default the proxy partially buffers responses. `flush_interval -1` disables buffering and flushes right after each write, and keeps the backend request alive even if the client disconnects early.
- The docs say `flush_interval` is ignored and responses are flushed immediately when the response has `Content-Type: text/event-stream`, when `Content-Length` is unknown, or (HTTP/2 both sides, unknown length, no `Accept-Encoding` or `identity`). So SSE streams without extra config, but always set `-1` for LLM routes: it also covers NDJSON (Ollama native API) and any chunked output.
- Never set `request_buffers` or `response_buffers` for LLM routes: the docs call both inefficient, and they delay the first token.
- Compression: `encode` does not compress `Content-Type: text/event-stream` or `Incremental: ?1` responses (documented under `minimum_length`), so SSE is safe. NDJSON is not named there: if tokens arrive late with `encode` on, exclude that route and test with `curl -N`.
- Since **v2.11.7** the proxy honours the `Incremental: ?1` header (RFC 10036): messages with it are forwarded as they arrive, and if configured buffering would block that, Caddy answers `501 Not Implemented` (set `proxy_status_name` to get a `Proxy-Status` header explaining it). Rarely relevant for LLM clients.

## Timeouts

Server-level (global options, `servers { timeouts { ... } }`), verified defaults:

| Option               | Default | Effect on LLM traffic                                                                                              |
| -------------------- | ------- | ------------------------------------------------------------------------------------------------------------------ |
| `read_header`        | `1m`    | slow request headers                                                                                               |
| `read_body_idle`     | `1m`    | an upload (image prompt) that stalls for 1 min is aborted; progress resets the clock                               |
| `write_idle`         | `1m`    | a **write to the client stalls** for 1 min and the connection is aborted; pauses between writes (SSE) do not count |
| `read_body`, `write` | none    | hard caps on the whole upload or response; avoid for streams                                                       |
| `idle`               | `5m`    | waiting for the next request on a keep-alive connection                                                            |

Do not use the `min_rate` argument of `write_idle` on streaming routes: the docs warn pauses count against the average rate.

Transport (`reverse_proxy { transport http { ... } }`):

| Option                          | Default | Advice                                                                                                                               |
| ------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `dial_timeout`                  | `3s`    | connect to the engine; raise only if it starts slowly                                                                                |
| `response_header_timeout`       | none    | **leave unset** for non-streaming completions on cold models (minutes)                                                               |
| `read_timeout`, `write_timeout` | none    | leave unset                                                                                                                          |
| `keepalive`                     | `2m`    | must be shorter than the backend's keep-alive idle timeout, or HTTP/1.1 upstreams can reset connections ("connection reset by peer") |
| `keepalive_idle_conns_per_host` | `32`    |                                                                                                                                      |

Caddy has no overall response-time cap by default, so unlike a Cloudflare edge there is no 125 s limit at this hop.

## Websockets

`reverse_proxy` upgrades WebSocket connections transparently (realtime or voice endpoints). On a config reload, WebSockets are closed by default, which also cuts long streams in the old config: set `stream_close_delay 5m` (keep streams until the delay passes) and optionally `stream_timeout 24h` to cull very old ones.

## Request body size

```caddy
request_body {
	max_size 50MB          # larger bodies get 413
}
```

Size for the largest prompt with embedded images (base64 inflates by about a third). Match it to the gateway's own limit.

## Headers and client IP

- `reverse_proxy` sets `X-Forwarded-For`, `-Proto` and `-Host` on proxied requests. **Incoming** `X-Forwarded-*` values are ignored unless the sender is a trusted proxy.
- If another proxy sits in front (cloudflared, Tailscale Serve), configure it so real client IPs reach logs and rate limits:

```caddy
{
	servers {
		trusted_proxies static private_ranges
		client_ip_headers X-Forwarded-For
	}
}
```

With a downstream that appends to the right of `X-Forwarded-For` also set `trusted_proxies_strict` (Caddy 2.8 or later). Tailscale Serve and cloudflared connect from loopback, which is in `private_ranges`.

- Rewrite Host for backends that check it: `header_up Host {upstream_hostport}` (used for Ollama, see `combos/forward-auth-llm.md`). The default passes the client's Host through.
- Remove a header before the upstream: `header_up -Cookie`.

## Health checks and several backends

```caddy
reverse_proxy 10.0.0.2:8000 10.0.0.3:8000 {
	lb_policy least_conn           # or round_robin (default is random)
	health_uri /health             # active checks (default interval 30s)
	fail_duration 30s              # passive: needs fail_duration
	flush_interval -1
}
```

Check the exact health endpoint of the engine (`/health` for vLLM and llama.cpp servers). Load balancing LLM replicas by connections is reasonable; sticky routing for prefix caches needs the gateway or a router (see `llm-gateway`).

## Verify

```bash
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
curl -N -sS -K - https://llm.example.com/v1/chat/completions -d '{"model":"<alias>","stream":true,"messages":[{"role":"user","content":"count to 20"}]}'
# headers (Authorization) via -K - from a 0600 file; chunks must arrive progressively
```

## Official links

- [reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Global options: timeouts, trusted_proxies](https://caddyserver.com/docs/caddyfile/options)
- [request_body](https://caddyserver.com/docs/caddyfile/directives/request_body)
- [header](https://caddyserver.com/docs/caddyfile/directives/header)
