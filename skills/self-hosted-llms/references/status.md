# Status snapshot

> Verified against llama-swap v263, LiteLLM v1.105.0, Docker Engine (CLI format strings), 2026-10-11

A read-only checklist to answer "what is running, is it healthy, and has anything drifted?".
Nothing here changes state or prints a secret. Run each block on node-a; the per-node blocks also on
node-b (`ssh node-b '<block>'` or a login there).

## Key handling for authenticated checks

Use a dedicated LiteLLM virtual key stored in a file you own (mode 600), not the master key:

```bash
KEY=$(< ~/.config/llm-stack/test.key)          # never echo "$KEY"
auth() { printf 'header = "Authorization: Bearer %s"\n' "$KEY" | curl -sS -K - "$@"; }
```

`printf` is a shell builtin, so the key never appears in the process list; curl reads the header
from stdin.

## Per node

```bash
hostname; uname -m; uptime
nvidia-smi --query-gpu=name,driver_version,temperature.gpu,power.draw --format=csv,noheader
free -h; swapon --show
df -h / "${HF_HOME:-$HOME/.cache/huggingface}" /var/lib/docker 2>/dev/null
for s in docker earlyoom llama-swap litellm llm-catalog cloudflared tailscaled; do
  printf '%-12s %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null)"
done
journalctl -u earlyoom -n 50 --no-pager | grep -m1 -i 'sending SIGTERM when'   # active thresholds
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' --filter label=llm-stack.role=engine
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
docker image ls --no-trunc --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' | sort
find "${HF_HOME:-$HOME/.cache/huggingface}/hub" -xtype l 2>/dev/null | wc -l     # dangling links
find /opt/llm-stack "${HF_HOME:-$HOME/.cache/huggingface}" -xdev ! -user "$(id -un)" 2>/dev/null | wc -l   # foreign-owned files
```

## Head node: routing and gateway

```bash
curl -s http://127.0.0.1:8080/health; echo                     # llama-swap
curl -s http://127.0.0.1:8080/running | jq .                   # loaded models and state
curl -s http://127.0.0.1:4000/health/liveliness; echo          # LiteLLM process
curl -s http://127.0.0.1:4000/health/readiness | jq '{status, litellm_version}'
auth http://127.0.0.1:8088/v1/models | jq -r '.data[] | [.id, (.context_length // "-")] | @tsv'
stat -c '%y %n' /var/lib/llm-stack/catalog/models.json        # catalog age vs last config change
```

## Configs, filtered

Show structure without credentials. Never `cat` env files, key files or unfiltered configs.

```bash
SECRETS='key|token|secret|password|credential'
grep -v -i -E "$SECRETS" /etc/llm-stack/llama-swap.yaml | grep -E '^\s*("?[a-z0-9-]+"?:|cmd|ttl|checkEndpoint|members)' | head -80
grep -v -i -E "$SECRETS" /etc/llm-stack/litellm-config.yaml | grep -E 'model_name|model:|api_base|model_group_alias|use_chat_completions_api|reasoning_effort'
sudo grep -v -i -E "$SECRETS" /etc/cloudflared/config.yml
systemctl cat litellm llama-swap | grep -v -i -E "$SECRETS"
docker inspect --format '{{.Name}} image={{.Config.Image}} id={{.Image}} restart={{.HostConfig.RestartPolicy.Name}}' $(docker ps -q) 2>/dev/null
```

Avoid `docker inspect` without `--format` and `{{.Config.Env}}`: container environments often hold
tokens.

## Drift against upstream

For each recipe or source checkout the stack builds from (examples: engine recipes, sparkDash):

```bash
for d in /opt/llm-stack/recipes/*/; do
  git -C "$d" fetch --quiet && printf '%s: %s behind\n' "$d" "$(git -C "$d" rev-list --count HEAD..@{u})"
done
```

Image drift between nodes (Rule 5):

```bash
for ref in $(docker ps --format '{{.Image}}' --filter label=llm-stack.role=engine | sort -u); do
  printf '%s\n  node-a %s\n  node-b %s\n' "$ref" \
    "$(docker image inspect --format '{{.Id}}' "$ref")" \
    "$(ssh node-b "docker image inspect --format '{{.Id}}' $ref" 2>/dev/null)"
done
```

## Exposure

```bash
systemctl status cloudflared --no-pager | head -5
journalctl -u cloudflared --since -1h --no-pager | grep -i -E 'registered|error|unreachable' | tail -5
tailscale serve status 2>/dev/null
```

## Report format

Summarize as: node, loaded model(s) and their group, engine containers per node, memory available
and swap used, disk free for weights, services not `active`, dangling links / foreign-owned files,
catalog age, image ID mismatches, recipe commits behind upstream. Then go to `troubleshooting.md`
for anything unhealthy.
