# Text Embeddings Inference

Run Hugging Face Text Embeddings Inference (TEI) beside a self-hosted LLM stack: pick the right image for the GPU, size memory, secure it, register embedding and rerank models in LiteLLM, and update or tear it down. Covers TEI only; vector stores have their own skills.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill text-embeddings-inference
```

## Rules

- **Ask before changing the system.** Containers, ports and gateway config need approval.
- **Secrets stay in `0600` files.** `API_KEY` and `HF_TOKEN` are never printed.
- **Bind to loopback or a private network.** TEI defaults to `0.0.0.0`.
- **Changing the embedding model means re-embedding.**

## References

- [`references/install.md`](references/install.md): image per GPU architecture, run, air-gapped.
- [`references/serve-config.md`](references/serve-config.md): flags and defaults.
- [`references/sizing.md`](references/sizing.md): VRAM and vector storage math.
- [`references/api.md`](references/api.md): routes and sample calls.
- [`references/security.md`](references/security.md): keys, binding, supply chain.
- [`references/updating.md`](references/updating.md): upgrade, rollback, teardown.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/`](references/combos): LiteLLM, llama-swap, Open WebUI.

## Companion skills

- `litellm`, `llama-swap`, `vllm`, `choosing-hardware`.

## License

MIT
