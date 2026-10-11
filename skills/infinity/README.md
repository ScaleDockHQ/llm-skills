# Infinity

Run Infinity (infinity_emb), a multi-model REST server for embeddings, rerankers, CLIP, ColBERT and classifiers, beside a self-hosted LLM stack: install, configure, size, secure, register in LiteLLM, update and tear down. Notes the project's slow release cadence.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill infinity
```

## Rules

- **Ask before changing the system.**
- **Secrets stay in `0600` files.**
- **Bind narrowly and set an API key.** `/health` is never authenticated.
- **Pin the version.** Last release was 0.0.77 (2025-08-22).

## References

- [`references/install.md`](references/install.md), [`serve-config.md`](references/serve-config.md), [`sizing.md`](references/sizing.md), [`api.md`](references/api.md), [`security.md`](references/security.md), [`updating.md`](references/updating.md), [`troubleshooting.md`](references/troubleshooting.md), [`combos/`](references/combos).

## Companion skills

- `text-embeddings-inference`, `litellm`, `llama-swap`, `vllm`.

## License

MIT
