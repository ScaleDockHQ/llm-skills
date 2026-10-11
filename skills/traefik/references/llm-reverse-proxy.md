# Traefik: fronting LLM servers

> Verified against Traefik v3.7.14 (docs for v3.7), 2026-10-11

Sources: reference "EntryPoints" (respondingTimeouts), "Service" (responseForwarding), middlewares "buffering", "forwardAuth", "compress", "serversTransport". Backend behavior from the respective product docs.

LLM APIs stream tokens over SSE for seconds to minutes. Checklist:

1. **Write timeout:** keep `writeTimeout` at its default `0s` on the entrypoint. A non-zero value cuts long generations.
2. **Read timeout:** default 60s covers reading the whole request including body; raise or set `0s` for very large prompts over slow links.
3. **Idle timeout:** default 180s for keep-alive; clients with long gaps reconnect, which is normal.
4. **No buffering middleware**, no `forwardAuth.forwardBody`, no response compression of `text/event-stream`.
5. **Flush:** streaming responses are flushed immediately; for odd backends set `responseForwarding.flushInterval: -1` (negative = flush after every write).
6. **Upstream timeouts:** do not set `responseHeaderTimeout` below the model's worst time to first token (reasoning models, cold swaps in `llama-swap`).
7. **WebSocket and HTTP/2:** check the entrypoint docs for the installed version; realtime endpoints need no streaming-specific middleware.
8. **Body size:** `buffering.maxRequestBodyBytes` caps uploads but buffers the body, so use it only on non-streaming routes.

Test:

```bash
curl -N https://llm.example.com/v1/chat/completions \
  -H "Authorization: Bearer $LLM_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"<alias>","stream":true,"messages":[{"role":"user","content":"count to 20"}]}' \
  | while IFS= read -r l; do printf '%s %s\n' "$(date +%S)" "${l:0:60}"; done
```

Timestamps must advance during the answer; if all lines print at the end, something buffers.

Backends: LiteLLM :4000, vLLM :8000, Ollama :11434, llama-swap (default 8080 per its docs, set by `--listen`). Keep the backend on localhost or a private network; Traefik is the only public listener.
