# llms-skills

Agent skills for choosing, running, connecting, improving and operating LLMs and generative-AI models: on a laptop, on your own GPU servers (NVIDIA DGX Spark first-class), or in the cloud. Each skill teaches an AI coding agent to inspect the live system first, follow verified upstream documentation, never print secrets, and measure before and after every change. The skills work with any agent that supports the [Agent Skills](https://agentskills.io/specification) format and install with the [skills CLI](https://github.com/vercel-labs/skills).

## Install

All skills:

```bash
npx skills add ScaleDockHQ/llms-skills
```

One skill:

```bash
npx skills add ScaleDockHQ/llms-skills --skill <name>
```

## Skills

### Decide

- [`choosing-llm-hosting`](skills/choosing-llm-hosting/): decide where models should run (local, owned server, rented GPUs, serverless, APIs or hybrid) and record the decision.
  `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`

### Run

- [`local-llms`](skills/local-llms/): run models on a laptop or desktop with Ollama, LM Studio, llama.cpp or MLX.
  `npx skills add ScaleDockHQ/llms-skills --skill local-llms`
- [`self-hosted-llms`](skills/self-hosted-llms/): serve models on your own NVIDIA Linux servers and DGX Spark as one authenticated endpoint (engines, llama-swap, LiteLLM, Cloudflare Tunnel or Tailscale).
  `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- [`cloud-llms`](skills/cloud-llms/): run and consume models in the cloud: APIs, GPU VMs, serverless GPUs and managed endpoints, with budgets and teardown.
  `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`
- [`self-hosted-genmedia`](skills/self-hosted-genmedia/): self-host image, video, speech-to-text and text-to-speech servers next to your LLMs.
  `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia`

### Connect

- [`llm-gateway`](skills/llm-gateway/): one OpenAI- and Anthropic-compatible gateway in front of many providers: keys, budgets, routing, fallbacks, API bridging.
  `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`
- [`llm-clients`](skills/llm-clients/): connect coding agents, IDEs, chat UIs and SDKs to any OpenAI- or Anthropic-compatible endpoint.
  `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`

### Improve

- [`llm-evals`](skills/llm-evals/): evaluate models and option changes on your own tasks against any OpenAI-compatible endpoint.
  `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
- [`model-quantization`](skills/model-quantization/): produce and publish quantized checkpoints (GGUF, EXL3, FP8, NVFP4 and more).
  `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`
- [`fine-tuning-llms`](skills/fine-tuning-llms/): fine-tune open-weight models locally or on rented GPUs, then serve the result.
  `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`

### Operate

- [`llm-observability`](skills/llm-observability/): metrics, tracing, logging, cost tracking and alerting for LLM serving and LLM apps.
  `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`

## Repository layout

```text
skills/<name>/
  SKILL.md        instructions the agent loads
  README.md       human overview: install, rules, references
  metadata.json   version, date, abstract, upstream references
  LICENSE         MIT
  references/     detailed, version-stamped guides loaded on demand
  templates/      config and shell templates (some skills)
  scripts/        bench.sh, a shared curl + jq benchmark (some skills)
tools/validate.sh structure and format checks for every skill
```

Run `tools/validate.sh` before opening a pull request.

## License

MIT
