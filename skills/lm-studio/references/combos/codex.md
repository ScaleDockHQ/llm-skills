# LM Studio with Codex

> Verified against LM Studio 0.4.26 (OpenAI-compatible `POST /v1/responses`) and lmstudio.ai/docs/integrations/codex, 2026-10-11

Codex CLI version not checked.

Codex talks to LM Studio through the Responses endpoint, enabled by Codex's `--oss` flag.

```bash
lms server start --port 1234
codex --oss                          # downloads and uses openai/gpt-oss-20b by default (ask before the large download)
codex --oss -m ibm/granite-4-micro   # any model available in LM Studio
```

## Pitfalls

- Use a model with more than about 25k tokens of context length (upstream tip). Preload with `lms load <model> --context-length 32768` rather than relying on JIT defaults.
- With **Require Authentication** on, `--oss` against LM Studio needs the token wired the way Codex expects. The LM Studio docs do not describe this (unverified); keep auth off on loopback or check Codex's docs for provider keys, and never print the token.
- `/v1/responses` supports stateful follow-ups through `previous_response_id`, tools, streaming and `reasoning.effort` (gpt-oss).
- Remote rig: LM Link (`combos/lm-link.md`) keeps `localhost:1234` on the laptop while the model runs elsewhere; `codex --oss -m <model>` works the same.

## Verify

```bash
curl -s http://localhost:1234/v1/responses -H 'Content-Type: application/json' \
  -d '{"model":"openai/gpt-oss-20b","input":"Reply with ok"}' | jq -r '.output[]? | select(.type=="message") | .content[0].text'
```

(The response shape follows OpenAI's Responses API; if `jq` returns nothing, print `jq .` to inspect it.)

## Official links

- https://lmstudio.ai/docs/integrations/codex
- https://lmstudio.ai/docs/developer/openai-compat/responses
