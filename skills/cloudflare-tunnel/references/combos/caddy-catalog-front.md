# Cloudflare Tunnel with a Caddy catalog front

> Verified against cloudflared 2026.10.0 and Caddy v2.11.7, 2026-10-11

Goal: clients that call `GET /v1/models` get an enriched model list (real `created` dates, `context_length`, capabilities) while every other request still goes straight to the gateway, and the gateway stays the only place that checks keys.

```text
GET /v1/models, /models ->  cloudflared (path ^/(v1/)?models/?$) -> Caddy 127.0.0.1:8088
                                forward_auth GET <gateway>/v1/models with the caller's headers
                                  2xx -> static models.json     other -> gateway's error unchanged
all other paths          ->  cloudflared -> gateway 127.0.0.1:4000
```

## Tunnel side

The ingress block (also in `assets/config.yml`), order matters:

```yaml
ingress:
  - hostname: llm.example.com
    path: ^/(v1/)?models/?$
    service: http://127.0.0.1:8088
  - hostname: llm.example.com
    service: http://127.0.0.1:4000
  - service: http_status:404
```

`path` is a Go regular expression and the path reaches Caddy unchanged. Check with `cloudflared --config /etc/cloudflared/config.yml tunnel ingress rule https://llm.example.com/v1/models` (expect the 8088 rule) and `.../v1/chat/completions` (expect 4000).

## Caddy side

Install the `caddy` skill and follow its model-catalog reference: `npx skills add ScaleDockHQ/llms-skills --skill caddy`. The Caddy site binds `127.0.0.1:8088` only.

## Pitfalls

- Catch-all or the plain-host rule above the path rule: the path rule never matches and clients get the gateway's thin list.
- Two spellings (`/models`, `/v1/models`): the regex covers both.
- The catalog is the same for every key; the gateway still refuses calls to models a key may not use.
- Over the tailnet there is no cloudflared: Tailscale Serve points at Caddy (8088), which proxies everything else to the gateway (`tailscale` skill).
