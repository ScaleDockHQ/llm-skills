# Streaming, timeouts and websockets

> Verified against cloudflared 2026.10.0 (docs: common tunnel errors, connection limits, error 524, WebSockets, run parameters), 2026-10-11

LLM traffic is long-lived and bursty, which is where proxies hurt. These are the documented behaviours.

## Streaming responses (SSE)

Cloudflare's troubleshooting page states that traffic through a tunnel is **buffered by default unless the origin responds with `Content-Type: text/event-stream`**; that header makes cloudflared stream data as it arrives.

- OpenAI-compatible `stream: true` responses (vLLM, llama.cpp, LiteLLM, Ollama `/v1`) are SSE with that content type, so they stream.
- Inference from the rule above (not tested): endpoints that stream with another content type, for example newline-delimited JSON such as Ollama's native `/api/chat` (`application/x-ndjson`), would be buffered. Prefer the `/v1` OpenAI-compatible routes through the tunnel, or test with `curl -N` and watch whether chunks arrive progressively.
- Test: `curl -N -sS -K - https://llm.example.com/v1/chat/completions -d '{"model":"<alias>","stream":true,"messages":[{"role":"user","content":"count to 20"}]}'` (headers via `-K -`, see `access-and-auth.md`). Tokens should appear one by one.
- A reverse proxy between the tunnel and the gateway must not buffer either: with Caddy use `flush_interval -1` (see the `caddy` skill; Caddy flushes `text/event-stream` responses immediately anyway).

## Time limits at Cloudflare's edge

From the connection-limits and error-524 pages:

| Limit                                               | Value                                                           | Result            |
| --------------------------------------------------- | --------------------------------------------------------------- | ----------------- |
| Proxy Read Timeout (origin sends no response bytes) | **125 s**; configurable only on Enterprise zones (up to 6000 s) | HTTP **524**      |
| Proxy Write Timeout                                 | 30 s, not configurable                                          | 524               |
| Proxy Idle Timeout                                  | 900 s                                                           | 520               |
| Client connection keep-alive / HTTP/2 idle          | 400 s                                                           | connection closed |

The 125 s clock is "time without a response". A stream that sends headers and first bytes early is not a 524 victim; a non-streaming request that computes for three minutes is. `originRequest` has connect, TLS and keep-alive settings only: there is no read timeout to raise in cloudflared.

Where this bites an LLM stack:

- **Non-streaming** completions for a big prompt or a cold model load.
- **Image or video generation** endpoints that return only when finished.
- **Reasoning models** that think silently before the first token on a non-streaming call.

Mitigations, in order: stream; send an early byte (some gateways emit loading or keep-alive events, see the gateway skill); keep hot models loaded; run long jobs over a path without Cloudflare's proxy (`tailscale`); use async job APIs with polling (Cloudflare itself suggests status polling for long HTTP processes).

## Websockets

Cloudflare supports proxied WebSocket connections without extra configuration (a zone toggle under Network > WebSockets exists; if upgrades fail, check it is on). Through a tunnel, long-lived connections like WebSockets are dropped when the cloudflared instance is stopped, for example on a config change, and Cloudflare notes maintenance can also cut them. Realtime or voice endpoints that use WebSockets need client reconnect logic.

## Disconnects of idle long-lived connections

If idle WebSocket or SSH-like sessions drop repeatedly, the docs suggest application-layer keepalives, trying `protocol: http2` for cloudflared (QUIC runs over UDP, which some firewalls and NAT devices time out quickly), and checking UDP idle timers. Set it in `config.yml` as `protocol: http2` or pass `--protocol http2`.

## Graceful shutdown

On SIGTERM cloudflared stops accepting requests and waits `--grace-period` (default 30 s) for in-flight ones, then exits. Streams longer than that are cut on restart. Raise `--grace-period` if you restart often while long generations run; with replicas (`updating.md`) new requests go to the other instance.

## Official links

- [Common errors: streaming buffered](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/troubleshoot-tunnels/common-errors/)
- [Connection limits](https://developers.cloudflare.com/fundamentals/reference/connection-limits/)
- [Error 524](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/error-524/)
- [WebSockets](https://developers.cloudflare.com/network/websockets/)
