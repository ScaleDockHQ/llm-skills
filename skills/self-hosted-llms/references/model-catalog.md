# Model catalog (enriched `/v1/models`)

> Verified against LiteLLM v1.105.0, Caddy v2.11.7, cloudflared 2026.10.0, 2026-10-11

## Why

Clients configure themselves from `GET /v1/models`: which models to list, how to sort them, how
much context to assume, whether to offer tools, vision or reasoning toggles. LiteLLM's list is thin:

- `created` is a fixed placeholder for every model (LiteLLM's `DEFAULT_MODEL_CREATED_AT_TIME`,
  1677610602, which is February 2023), so clients that sort or label by date show every model as
  equally old.
- No context length, so clients fall back to a small default and truncate long chats early.

That combination confused LobeHub in this stack: wrong ordering and a small assumed context. The
fix keeps LiteLLM as the only authentication point and serves a static, enriched list instead.

## How it works

```text
GET /v1/models  ->  cloudflared (path ^/(v1/)?models/?$)  ->  Caddy 127.0.0.1:8088
                    Caddy forward_auth: GET 127.0.0.1:4000/v1/models with the caller's headers
                      2xx -> serve /var/lib/llm-stack/catalog/models.json
                      401 -> LiteLLM's error is returned unchanged
all other paths  -> cloudflared -> LiteLLM 127.0.0.1:4000   (Tailscale: Caddy proxies them)
```

- `templates/build-catalog.sh` fetches LiteLLM's list with a key (from `LLM_API_KEY` or a key file,
  never printed), merges `catalog.json` by model name (and `aliases` for `model_group_alias`
  names), and writes `models.json` atomically. It warns about models with no entry (`--strict` fails).
- `templates/catalog.example.json` shows the fields: `created` (real release date, Unix time),
  `name`, `description`, `context_length`, `max_model_len`, `max_output_tokens`, `capabilities`.
  Any extra key is copied through, so add what your clients read.
- `templates/Caddyfile` does the auth check and serving; `templates/systemd/llm-catalog.service`
  runs it.

Which extension fields a given client reads differs and changes between client versions: check the
client's docs (the `llm-clients` skill has per-client notes). Engines use these names in their
own lists: vLLM `max_model_len`, TensorFold both `context_length` and `max_model_len`.

## Setup

```bash
sudo install -d -o llm -g llm /var/lib/llm-stack/catalog
sudo install -m 644 templates/catalog.example.json /opt/llm-stack/catalog.json   # then edit
sudo install -m 755 templates/build-catalog.sh /opt/llm-stack/
sudo install -m 644 templates/Caddyfile /etc/llm-stack/Caddyfile
sudo -u llm -H sh -c 'LLM_KEY_FILE="$HOME/.config/llm-stack/catalog.key" /opt/llm-stack/build-catalog.sh'
sudo systemctl enable --now llm-catalog
```

Give the build its own virtual key file (mode 600, owned by the service user). The script also
accepts an env file with a `LITELLM_MASTER_KEY=` line, but a narrow key is better.

Rebuild after every model change (new LiteLLM entry, alias, catalog edit). Caddy serves the file
from disk, so no reload is needed.

## Verify

```bash
KEY=$(< ~/.config/llm-stack/test.key)
printf 'header = "Authorization: Bearer %s"\n' "$KEY" |
  curl -sS -K - https://llm.example.com/v1/models | jq -r '.data[] | "\(.id)\t\(.context_length)\t\(.created)"'
curl -s -o /dev/null -w '%{http_code}\n' https://llm.example.com/v1/models      # expect 401
```

## Known pitfalls

- **Same list for every key.** The static file lists all models; LiteLLM's own list can be filtered
  per key. If keys have different model access, either accept that clients see names they cannot
  call (requests are still refused by LiteLLM), or skip the catalog for those keys.
- **Stale file.** A new model works but does not show up in clients until the catalog is rebuilt.
- **Missing path rule.** Without the cloudflared rule (or with the catch-all above it), `/v1/models`
  goes to LiteLLM and clients get the thin list again. Rules match top to bottom.
- **Both `/models` and `/v1/models`.** Some clients call one, some the other; the Caddyfile and the
  ingress regex cover both.
- **forward_auth uri.** The check must hit an endpoint any valid key may call; `/v1/models` is.

## Official links

- [Caddy forward_auth](https://caddyserver.com/docs/caddyfile/directives/forward_auth)
- [Caddy file_server](https://caddyserver.com/docs/caddyfile/directives/file_server)
- [cloudflared ingress rules](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/)
- [OpenAI models object](https://platform.openai.com/docs/api-reference/models/object)
