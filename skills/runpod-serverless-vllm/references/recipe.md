# Recipe: worker-vllm on Runpod Serverless

> Verified against runpod-workers/worker-vllm v2.29.0 README, docs.runpod.io (Deploy vLLM on Runpod Serverless, vLLM OpenAI compatibility), runpodctl v2.15.0, 2026-10-11

The commands below tie the product skills together. Details, flags and failure modes live in the `runpod` skill (`serverless-vllm.md`, `limits-and-costs.md`, `troubleshooting.md`) and the `vllm` skill.

## 0. Decide the inputs (ask the user)

| Input           | Example                             | Where to decide                                |
| --------------- | ----------------------------------- | ---------------------------------------------- |
| Model           | `Qwen/Qwen3-8B`                     | `vllm`, `choosing-hardware`                    |
| `MAX_MODEL_LEN` | `8192`                              | too large fails startup with a `startup_error` |
| GPU type        | from `runpodctl gpu list`           | VRAM must fit weights plus KV cache            |
| `--workers-max` | `1` or `2` to start                 | this is the spend cap                          |
| Served name     | `OPENAI_SERVED_MODEL_NAME_OVERRIDE` | short, stable name for clients                 |

## 1. Pre-flight

```bash
export RUNPOD_API_KEY="$(cat ~/.config/runpod/api-key)"      # file is 0600; never echo it
runpodctl user | jq 'del(.email, .id)'                        # spend limit and per-hour baseline
runpodctl gpu list | head -20                                  # ids and availability, no prices copied into notes
curl -s https://api.github.com/repos/runpod-workers/worker-vllm/releases/latest | jq -r .tag_name
```

Use the printed tag below as `<version>`. Never deploy `:latest`.

## 2. Create template and endpoint (after approval)

```bash
runpodctl template create --serverless --name vllm-llm \
  --image runpod/worker-v1-vllm:<version> \
  --env '{"MODEL_NAME":"Qwen/Qwen3-8B","MAX_MODEL_LEN":"8192","OPENAI_SERVED_MODEL_NAME_OVERRIDE":"llm"}'
runpodctl serverless create --name vllm-llm --template-id <template-id> \
  --gpu-id "<gpu id from the list>" --workers-min 0 --workers-max 1
```

- A Serverless template binds to one endpoint; create one template per endpoint.
- Gated model: store `HF_TOKEN` as a Runpod secret and reference it as `{{ RUNPOD_SECRET_<name> }}` in the template environment (see `runpod` `setup-and-auth.md`); never inline it in the command.
- Tool calling needs `ENABLE_AUTO_TOOL_CHOICE` and `TOOL_CALL_PARSER` (see `tool-calling-parsers` skill).
- Cached models: set the endpoint's model reference (`--model-reference`) so weights are placed ahead of time. See `runpod` `serverless-vllm.md`.
- If the worker cannot start for a non-retryable reason (out of memory, gated model without token, context too large), it returns a JSON `startup_error` instead of crash-looping. Read `runpodctl serverless logs <id>`.

## 3. Smoke test

```bash
export ENDPOINT_ID=<id from runpodctl serverless list>
runpodctl serverless health "$ENDPOINT_ID"
# first call waits for a cold start: use a long client timeout
curl -sS --max-time 600 "https://api.runpod.ai/v2/$ENDPOINT_ID/openai/v1/models" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" | jq -r '.data[].id'
curl -sS --max-time 600 "https://api.runpod.ai/v2/$ENDPOINT_ID/openai/v1/chat/completions" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"llm","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq -r '.choices[0].message.content'
```

The `model` value must equal `MODEL_NAME`, or the served-name override when set. A `401` means a wrong key; `429` means rate limiting (retry with backoff). Then wait for idle and confirm workers return to zero in `runpodctl serverless health`.

## 4. Stack-specific pitfalls

| Pitfall                                  | Fix                                                                                     |
| ---------------------------------------- | --------------------------------------------------------------------------------------- |
| First request times out                  | Cold start is worker boot plus model load; use a client timeout of several minutes.     |
| Gateway model name mismatch              | `openai/<served-name>`, where served name is `MODEL_NAME` or the override.              |
| Endpoint stops answering after idle days | Runpod lowers max workers after long idle (to 0 after 7 days); raise `--workers-max`.   |
| Unexpected spend                         | Active workers above 0, or max workers too high. Check `runpodctl serverless get <id>`. |
| Need no queue or a custom server         | Use a load-balancing endpoint instead (`runpod` skill), with a different LiteLLM entry. |
