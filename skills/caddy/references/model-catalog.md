# Model catalog: an enriched `/v1/models`

> Verified against Caddy v2.11.7 (docs: forward_auth, file_server, handle; catalog path tested locally with Caddy v2.11.7 and a mock gateway), LiteLLM v1.105.0 behaviour as recorded in the self-hosted stack, cloudflared 2026.10.0, 2026-10-11

## Why

Clients configure themselves from `GET /v1/models`: which models to list, how to sort them, how much context to assume, whether to offer tools, vision or reasoning toggles. A gateway's list is often thin:

- LiteLLM reports one fixed placeholder `created` value for every model (its `DEFAULT_MODEL_CREATED_AT_TIME`, 1677610602, February 2023), so clients that sort or label by date show all models as equally old.
- No context length, so clients fall back to a small default and truncate long chats early.

(The LiteLLM behaviour is carried over from this stack's earlier notes and was not re-verified against LiteLLM source in this pass: check `GET /v1/models` on your version.) LobeHub showed both symptoms in this stack. The fix keeps the gateway as the only authentication point and serves a static, enriched list instead. This is a stack-specific technique (not a Caddy feature); the Caddy parts are `forward_auth` and `file_server`.

## How it works

```text
GET /v1/models  ->  (tunnel path rule or Serve)  ->  Caddy 127.0.0.1:8088
                    forward_auth: GET <gateway>/v1/models with the caller's headers
                      2xx -> serve /var/lib/llm-stack/catalog/models.json
                      401 -> the gateway's error is returned unchanged
all other paths  ->  gateway (cloudflared sends them straight; with Tailscale Serve, Caddy proxies them)
```

Pieces in `assets/`:

- `Caddyfile.catalog`: the loopback site: `handle @models` for `/v1/models`, `/v1/models/`, `/models`, `/models/`, and a default `handle` that reverse-proxies to the gateway with `flush_interval -1`.
- `build-catalog.sh`: fetches the gateway's list with a key (from `LLM_API_KEY` or a key file, never printed), merges `catalog.json` per model (and `aliases` for model-group aliases), and writes `models.json` atomically. It warns about models without a catalog entry; `--strict` fails. Needs bash, curl and jq.
- `catalog.example.json`: fields `created` (real release date, Unix time), `name`, `description`, `context_length`, `max_model_len`, `max_output_tokens`, `capabilities`, plus any extra keys your clients read. `defaults` is merged into every entry.
- `llm-catalog.service`: systemd unit running a dedicated Caddy as user `llm`.

Which extension fields a client reads differs by client and version: check the client's docs (the `llm-clients` skill has per-client notes). Engines use their own names: vLLM `max_model_len`; some servers expose both `context_length` and `max_model_len`.

## Setup

```bash
sudo install -d -o llm -g llm /var/lib/llm-stack/catalog
sudo install -m 644 assets/catalog.example.json /opt/llm-stack/catalog.json      # then edit
sudo install -m 755 assets/build-catalog.sh /opt/llm-stack/
sudo install -m 644 assets/Caddyfile.catalog /etc/llm-stack/Caddyfile
sudo install -m 644 assets/llm-catalog.service /etc/systemd/system/
sudo -u llm -H sh -c 'LLM_KEY_FILE="$HOME/.config/llm-stack/catalog.key" /opt/llm-stack/build-catalog.sh'
sudo systemctl daemon-reload && sudo systemctl enable --now llm-catalog
```

Give the build its own **virtual key** in a `0600` file owned by the service user (the script also accepts an env file with a `LITELLM_MASTER_KEY=` line, but a narrow key is better). Rebuild after every model change (new entry, alias, catalog edit). Caddy reads the file from disk, so no reload is needed.

Wire the front in:

- **Cloudflare Tunnel:** a path rule `^/(v1/)?models/?$` to `http://127.0.0.1:8088` above the gateway rule (see `cloudflare-tunnel`).
- **Tailscale Serve:** `sudo tailscale serve --bg --https=443 http://127.0.0.1:8088`; Caddy proxies everything else to the gateway (see `tailscale`).

The site must accept the hostname used (an address-only `:8088` site does).

## Verify

```bash
KEY=$(< ~/.config/llm-stack/test.key)
printf 'header = "Authorization: Bearer %s"\n' "$KEY" |
  curl -sS -K - https://llm.example.com/v1/models | jq -r '.data[] | "\(.id)\t\(.context_length)\t\(.created)"'
curl -s -o /dev/null -w '%{http_code}\n' https://llm.example.com/v1/models      # expect 401
```

## Known pitfalls

- **Same list for every key.** The static file lists all models; the gateway's own list can be filtered per key. With per-key model access, clients may see names they cannot call (the gateway still refuses). Skip the catalog for those keys if that matters.
- **Stale file.** A new model works but is not listed until the catalog is rebuilt.
- **Missing path rule.** If `/v1/models` reaches the gateway directly (catch-all above the path rule), clients get the thin list.
- **Both `/models` and `/v1/models`.** Some clients call one, some the other; the matcher covers both.
- **`forward_auth` uri.** The check must hit an endpoint any valid key may call; `/v1/models` is.

## Official links

- [forward_auth](https://caddyserver.com/docs/caddyfile/directives/forward_auth)
- [file_server](https://caddyserver.com/docs/caddyfile/directives/file_server)
- [handle](https://caddyserver.com/docs/caddyfile/directives/handle)
- [OpenAI models object](https://platform.openai.com/docs/api-reference/models/object)
