# exo Skill

An agent skill for [exo](https://github.com/exo-explore/exo), the open-source runtime that connects Macs and other devices into one AI cluster. It covers the macOS app and source installs, automatic discovery and namespaces, enabling RDMA over Thunderbolt 5, pipeline versus tensor placements, the instance lifecycle API, OpenAI, Claude Messages, Responses and Ollama compatible endpoints, custom Hugging Face models, benchmarking, updating and troubleshooting. Every command is read-only first and never prints secrets.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill exo
```

## Rules

- **Ask before changing the system.** Network profiles, Recovery-mode RDMA and exposure need approval.
- **No API auth is documented.** Keep port 52415 on a trusted network or behind a proxy.
- **Match versions** on every node, including macOS for RDMA.
- **Wait for instances** before inference.
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): app, Homebrew, source, uninstall.
- [`references/serve-config.md`](references/serve-config.md): flags, ports, environment variables.
- [`references/parallelism-multinode.md`](references/parallelism-multinode.md): discovery, sharding, RDMA.
- [`references/api.md`](references/api.md): instance lifecycle and inference endpoints.
- [`references/models-and-storage.md`](references/models-and-storage.md): models, custom models, directories.
- [`references/integrations.md`](references/integrations.md): clients and gateways.
- [`references/performance-tuning.md`](references/performance-tuning.md): bench and tuning.
- [`references/updating.md`](references/updating.md): updates.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

`mlx`, `local-llms`, `nccl-rdma-networking`, `llm-gateway`, `litellm`, `tailscale`.

## License

MIT
