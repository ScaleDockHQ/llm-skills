# Mac cluster with exo and MLX

Cluster two or more Apple Silicon Macs into one inference host with exo (automatic discovery, dashboard, OpenAI, Claude Messages, Responses and Ollama-compatible APIs) or MLX distributed (`mlx.launch` with `mlx_lm.server`), over Thunderbolt 5 with RDMA when available, or ring over TCP.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill mac-cluster-exo-mlx
```

## Rules

- **Ask before `rdma_ctl enable`,** network changes and installs; it needs Recovery mode and a reboot per node.
- **Match macOS versions exactly** across RDMA nodes.
- **Full Thunderbolt 5 mesh** for RDMA: every node cabled to every other node.
- **No public exposure.** Keep the API on the private network behind a gateway.

## References

- [`references/recipe.md`](references/recipe.md): end-to-end plan and sizing.
- [`references/networking-and-rdma.md`](references/networking-and-rdma.md): mesh, `rdma_ctl`, ring versus JACCL.
- [`references/exo.md`](references/exo.md): install, configuration, API.
- [`references/mlx-distributed.md`](references/mlx-distributed.md): hostfiles, `mlx.launch`, `mlx_lm.server`.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/updating.md`](references/updating.md): upgrades.

## Companion skills

- `mlx`, `apple-silicon`: one-Mac depth.
- `tailscale`, `llm-gateway`, `litellm`: access and routing.
- `exo`: not yet published; install later.

## License

MIT
