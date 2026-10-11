# Self-Hosted LLMs Skill

An agent skill for running your own LLM and generative-AI servers on Linux hosts with NVIDIA GPUs, with NVIDIA DGX Spark (single node or two nodes over ConnectX-7) as the first-class profile. It walks an AI coding agent through discovering the live system, planning memory, preparing hosts, downloading pinned weights safely, serving models with engines such as [vLLM](https://github.com/vllm-project/vllm), [SGLang](https://github.com/sgl-project/sglang), [TensorRT-LLM](https://github.com/NVIDIA/TensorRT-LLM), [llama.cpp](https://github.com/ggml-org/llama.cpp), [Ollama](https://github.com/ollama/ollama), [ExLlamaV3](https://github.com/turboderp-org/exllamav3), TensorFold and [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp), swapping them with [llama-swap](https://github.com/mostlygeek/llama-swap), and publishing one authenticated OpenAI-compatible endpoint through a [LiteLLM](https://github.com/BerriAI/litellm) gateway, an enriched model catalog, and [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/) or [Tailscale Serve](https://tailscale.com/kb/1312/serve). It also covers benchmarking, optimization, upstream updates, cleanup and troubleshooting. Status commands are read-only and never print secrets.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms
```

## Rules

- **One endpoint, many models.** Clients see stable model names; the gateway routes, the swapper manages lifecycle.
- **Measure before and after.** No update or optimization without a baseline and the same protocol afterwards.
- **Download while serving, rebuild while stopped.** On unified memory, compiles and unbounded downloads can kill a serving node.
- **Cap every background job.** Downloads, rsyncs and builds run in memory-limited scopes.
- **Both nodes, always.** Images, weights and configs must match on every node; verify image IDs, not tags.
- **Downtime is a decision.** Announce expected duration and get confirmation before stopping a public endpoint.
- **Secrets never touch output.** Read keys in subshells; never echo, log, commit or tee them.
- **Numerics-changing options need a quality gate.** Quantization, KV-cache dtype, speculative decoding or a new engine pass a task eval (`llm-evals`), not only a speed benchmark.
- **Clean up only after verification**, and ask before deleting weights or rollback paths.
- **Services, not nohup.** Anything that must survive a reboot or outage is a systemd unit.

## References

- [`references/architecture.md`](references/architecture.md): Reference stack, request path, port map, layering options.
- [`references/hardware-dgx-spark.md`](references/hardware-dgx-spark.md): GB10 unified memory, single vs dual node, ConnectX-7, memory budgeting.
- [`references/hardware-generic.md`](references/hardware-generic.md): Other NVIDIA Linux hosts, multi-GPU, VRAM vs UMA, rented GPU VMs.
- [`references/host-setup.md`](references/host-setup.md): OS prep, Docker, NVIDIA Container Toolkit, SSH between nodes, disks, units.
- [`references/memory-safety.md`](references/memory-safety.md): earlyoom, capped scopes, container memory limits.
- [`references/models-and-weights.md`](references/models-and-weights.md): Formats and quants, HF CLI, cache layout, revisions, syncing nodes.
- [`references/status.md`](references/status.md): Read-only status snapshot checklist.
- [`references/smoke-test.md`](references/smoke-test.md): curl + jq checks through the public URL.
- [`references/engine-vllm.md`](references/engine-vllm.md): vLLM.
- [`references/engine-tensorfold.md`](references/engine-tensorfold.md): TensorFold and DGX Spark recipes.
- [`references/engine-exllama.md`](references/engine-exllama.md): ExLlamaV3 / EXL3 via TabbyAPI or an OpenAI server.
- [`references/engine-sglang.md`](references/engine-sglang.md): SGLang.
- [`references/engine-trtllm.md`](references/engine-trtllm.md): TensorRT-LLM (`trtllm-serve`).
- [`references/engine-llamacpp.md`](references/engine-llamacpp.md): llama.cpp `llama-server` + GGUF.
- [`references/engine-ollama.md`](references/engine-ollama.md): Ollama as a backend.
- [`references/engine-sdcpp.md`](references/engine-sdcpp.md): stable-diffusion.cpp `sd-server`; ComfyUI alternative.
- [`references/adding-a-server.md`](references/adding-a-server.md): Backend contract and step-by-step with worked examples.
- [`references/llama-swap.md`](references/llama-swap.md): Swapping, groups, timeouts, filters, hooks, API.
- [`references/litellm.md`](references/litellm.md): Stack-specific LiteLLM minimum.
- [`references/model-catalog.md`](references/model-catalog.md): Enriched static `/v1/models` behind Caddy forward_auth.
- [`references/reasoning-effort.md`](references/reasoning-effort.md): Per-model effort values and config-only mapping.
- [`references/exposure-cloudflare.md`](references/exposure-cloudflare.md): Tunnel as a service, ingress, Access, timeouts.
- [`references/exposure-tailscale.md`](references/exposure-tailscale.md): Tailscale Serve, certificates, key expiry.
- [`references/monitoring-sparkdash.md`](references/monitoring-sparkdash.md): sparkDash install, probes, allow-list, shutdown helper.
- [`references/benchmarking.md`](references/benchmarking.md): Fixed protocol with `scripts/bench.sh`.
- [`references/optimization.md`](references/optimization.md): Evaluating opt-ins: gain, cost, numerics, A/B, gates.
- [`references/updating.md`](references/updating.md): Upstream update workflow, image drift, rollback.
- [`references/cleanup.md`](references/cleanup.md): Safe cleanup order, HF orphans, root-owned files.
- [`references/clients.md`](references/clients.md): Stack-specific client notes and short snippets.
- [`references/security.md`](references/security.md): Secrets, sudo scope, least exposure.
- [`references/troubleshooting.md`](references/troubleshooting.md): Symptom -> cause -> fix.
- [`references/example.md`](references/example.md): Anonymized worked example: 2x DGX Spark, 4 models, one endpoint.

Templates: [`assets/llama-swap.yaml`](assets/llama-swap.yaml), [`assets/litellm-config.yaml`](assets/litellm-config.yaml), [`assets/build-catalog.sh`](assets/build-catalog.sh), [`assets/catalog.example.json`](assets/catalog.example.json), [`assets/Caddyfile`](assets/Caddyfile), [`assets/cloudflared-config.yml`](assets/cloudflared-config.yml), [`assets/start-model.sh`](assets/start-model.sh), [`assets/common.sh`](assets/common.sh), [`assets/models.d/example-vllm.sh`](assets/models.d/example-vllm.sh), [`assets/systemd/`](assets/systemd/).

Script: [`scripts/bench.sh`](scripts/bench.sh), a curl + jq benchmark for any OpenAI-compatible endpoint (TTFB, decode, prefill and aggregate tok/s; `--help` for usage).

## Companion skills

From [ScaleDockHQ/llms-skills](https://github.com/ScaleDockHQ/llms-skills); install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `stable-diffusion-cpp`: sd-server depth; engine-sdcpp is now a stack note.
- `choosing-llm-hosting`: decide local vs self-hosted vs cloud vs hybrid before building anything.
- `local-llms`: laptops and desktops (Ollama, LM Studio, llama.cpp, MLX).
- `cloud-llms`: frontier and open-model APIs, GPU VMs, serverless GPU, managed endpoints.
- `self-hosted-genmedia`: image, video and speech servers in depth (ComfyUI, sd.cpp, Whisper, TTS).
- `llm-gateway`: LiteLLM and alternatives: keys, budgets, routing, fallbacks, API bridging.
- `llm-clients`: per-client configuration for IDEs, CLIs, chat UIs and SDKs.
- `llm-evals`: quality gates and task evals for model or option changes.
- `model-quantization`: producing EXL3, NVFP4, FP8 and GGUF quants.
- `fine-tuning-llms`: training adapters or full fine-tunes to serve here.
- `llm-observability`: metrics, logs and tracing beyond the built-in endpoints.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `exllamav3`, `tensorfold`: engine depth.
- `llama-swap`: router depth.
- `nvidia-dgx-spark`: DGX Spark platform depth.
- `litellm`, `cloudflare-tunnel`, `tailscale`: gateway and exposure depth.

## License

MIT
