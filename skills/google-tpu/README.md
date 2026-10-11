# Google TPU

Helps an agent choose, provision and operate Google Cloud TPUs (v5e, v6e Trillium, TPU7x Ironwood) for LLM serving with vLLM TPU (`vllm-tpu`, `tpu-inference`). It covers generations and HBM sizing, Compute Engine, Cloud TPU API and GKE provisioning, the vLLM TPU install and serve path, TPU-specific failures and teardown.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill google-tpu
```

## Rules

- **Ask before billing.** TPU VMs, queued resources, node pools and reservations cost money; get approval first.
- **Match the API to the generation.** The Cloud TPU API does not support TPU7x; use Compute Engine or GKE.
- **Pin versions.** Pin `vllm-tpu` or the image tag, the model revision and the runtime; never `latest`.
- **Keep secrets out of sight.** `HF_TOKEN` comes from a `0600` file or the environment and is never printed.
- **Warm up before measuring.** XLA compiles per shape.
- **Always tear down.** Verify nothing TPU-related remains.

## References

- [`references/generations-and-sizing.md`](references/generations-and-sizing.md): v5e, v6e and TPU7x specs, slices, HBM budget.
- [`references/provisioning.md`](references/provisioning.md): Compute Engine, queued resources, GKE, capacity models.
- [`references/vllm-tpu.md`](references/vllm-tpu.md): install, image, serve, env vars, supported models.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to fix.
- [`references/teardown.md`](references/teardown.md): ordered removal and verification.

## Companion skills

- `vllm`: engine flags and tuning.
- `google-vertex-ai`: managed Gemini and Model Garden.
- `litellm`: gateway in front of the endpoint.
- `choosing-hardware`: compare TPU and GPU options.
- `cloud-llms`: other providers.

## License

MIT
