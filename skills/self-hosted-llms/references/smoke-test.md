# Smoke test

> Verified against LiteLLM v1.105.0 (chat, /v1/messages, /v1/responses, images routes), curl and jq, 2026-10-11

Run after any change, first on loopback (`http://127.0.0.1:4000`), then through the public URL.
Each check prints one line; anything other than `ok` needs a look.

```bash
BASE=${BASE:-https://llm.example.com}
KEY=$(< ~/.config/llm-stack/test.key)              # a virtual key; never echo it
HDR=$(mktemp); chmod 600 "$HDR"; trap 'rm -f "$HDR"' EXIT
printf 'header = "Authorization: Bearer %s"\n' "$KEY" > "$HDR"   # curl config file, not argv
auth() { curl -sS -K "$HDR" --max-time 900 "$@"; }
MODEL=${MODEL:-coder}
J='Content-Type: application/json'
```

## 1. Authentication is enforced

```bash
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/v1/models")
[ "$code" = 401 ] && echo "auth: ok" || echo "auth: expected 401, got $code"
```

A 200 here means the catalog or gateway is open to the internet: stop and fix before anything else.

## 2. Model list (catalog)

```bash
auth "$BASE/v1/models" | jq -r '.data[] | "\(.id)\tctx=\(.context_length // "missing")\tcreated=\(.created)"'
```

Expect every public name, a context length per chat model, and real `created` dates (not one
identical placeholder for all).

## 3. Chat completion, non-streaming

```bash
auth -H "$J" "$BASE/v1/chat/completions" -d "{\"model\":\"$MODEL\",\"max_tokens\":32,
  \"messages\":[{\"role\":\"user\",\"content\":\"Reply with the word ok.\"}]}" |
  jq -r 'if .choices[0].message.content then "chat: ok" else "chat: \(.error // .)" end'
```

## 4. Streaming

```bash
auth -N -H "$J" "$BASE/v1/chat/completions" -d "{\"model\":\"$MODEL\",\"max_tokens\":32,\"stream\":true,
  \"messages\":[{\"role\":\"user\",\"content\":\"Count to five.\"}]}" |
  grep -c '^data: ' | awk '{print ($1>2) ? "stream: ok ("$1" events)" : "stream: only "$1" events"}'
```

## 5. Anthropic Messages bridge

```bash
auth -H "$J" "$BASE/v1/messages" -d "{\"model\":\"$MODEL\",\"max_tokens\":32,
  \"messages\":[{\"role\":\"user\",\"content\":\"Reply with the word ok.\"}]}" |
  jq -r 'if (.content // [] | map(select(.type=="text")) | length) > 0 then "messages: ok" else "messages: \(.error // .)" end'
```

## 6. Responses API, twice on one connection

The second request on the same keep-alive connection catches the broken-route failure described in
`litellm.md`.

```bash
body="{\"model\":\"$MODEL\",\"input\":\"Reply with the word ok.\",\"max_output_tokens\":32}"
auth -H "$J" "$BASE/v1/responses" -d "$body" -o /tmp/r1.json \
  --next -sS -K "$HDR" -H "$J" "$BASE/v1/responses" -d "$body" -o /tmp/r2.json
for f in /tmp/r1.json /tmp/r2.json; do
  jq -r --arg f "$f" 'if [.output[]? | select(.type=="message")] | length > 0 then "responses \($f): ok" else "responses \($f): \(.error // .)" end' "$f"
done
rm -f /tmp/r1.json /tmp/r2.json
```

(`--next` resets per-transfer options, so the header file is passed again; curl reuses the connection.)

## 7. Tool calling

```bash
auth -H "$J" "$BASE/v1/chat/completions" -d "{\"model\":\"$MODEL\",\"max_tokens\":128,
  \"messages\":[{\"role\":\"user\",\"content\":\"What is the weather in Paris? Use the tool.\"}],
  \"tools\":[{\"type\":\"function\",\"function\":{\"name\":\"get_weather\",
    \"parameters\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}},\"required\":[\"city\"]}}}]}" |
  jq -r 'if .choices[0].message.tool_calls then "tools: ok" else "tools: no tool_calls" end'
```

`no tool_calls` usually means the engine was started without its tool-call parser
(see the engine reference).

## 8. Reasoning variants

```bash
for m in gpt-oss gpt-oss-high qwen-coder-nothink; do
  auth -H "$J" "$BASE/v1/chat/completions" -d "{\"model\":\"$m\",\"max_tokens\":256,
    \"messages\":[{\"role\":\"user\",\"content\":\"What is 17*23?\"}]}" |
    jq -r --arg m "$m" '"\($m): reasoning=\(.choices[0].message.reasoning_content // "" | length) chars, completion_tokens=\(.usage.completion_tokens)"'
done
```

Expect more reasoning for `-high` than the default, and none for `-nothink`. Mapping details in
`reasoning-effort.md`.

## 9. Image generation (if served)

```bash
auth -H "$J" "$BASE/v1/images/generations" -d '{"model":"image-sd","prompt":"a red cube on a table","size":"512x512","n":1}' |
  jq -r 'if (.data[0].b64_json // .data[0].url) then "image: ok" else "image: \(.error // .)" end'
```

## 10. Cold swap timing

```bash
auth -o /dev/null -w 'cold swap: %{http_code} in %{time_total}s\n' -H "$J" "$BASE/v1/chat/completions" \
  -d '{"model":"gpt-oss","max_tokens":8,"messages":[{"role":"user","content":"hi"}]}'
```

A non-streaming cold swap through Cloudflare that takes longer than the proxy read timeout returns 524. Streaming requests survive because llama-swap sends loading progress
(`exposure-cloudflare.md`).

## Official links

- [LiteLLM /v1/messages](https://docs.litellm.ai/docs/anthropic_unified)
- [LiteLLM /responses](https://docs.litellm.ai/docs/response_api)
- [curl manual](https://curl.se/docs/manpage.html)
