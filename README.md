# llms-skills

Agent skills for choosing, running, connecting, improving and operating LLMs and generative-AI models: on a laptop, on your own GPU servers (NVIDIA DGX Spark first-class), or in the cloud. Each skill teaches an AI coding agent to inspect the live system first, follow verified upstream documentation, never print secrets, and measure before and after every change. The skills work with any agent that supports the [Agent Skills](https://agentskills.io/specification) format (Cursor, Claude Code, Codex, and others) and install with the [skills CLI](https://github.com/vercel-labs/skills).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills
```

The CLI lists every skill in this repo and asks which ones to install (space to toggle). To skip the picker:

```bash
# See what's available
npx skills add ScaleDockHQ/llms-skills --list

# Install one or more skills by name
npx skills add ScaleDockHQ/llms-skills --skill local-llms

# Same thing, shorter
npx skills add ScaleDockHQ/llms-skills@local-llms
```

Add `-g` to install globally (user level) instead of per project. Run `npx skills update` to pull the latest versions.

## Skills

Every skill has a `kind` (see `metadata.json`):

| Kind           | What it is                                                                   |
| -------------- | ---------------------------------------------------------------------------- |
| `workflow`     | Decide, run, connect, improve or operate: the entry points, listed below.    |
| `product`      | One tool or service in depth (for example an inference engine or a gateway). |
| `platform`     | A hardware platform or a cloud provider.                                     |
| `technique`    | A cross-product architecture technique (for example speculative decoding).   |
| `model-family` | Chat templates, parsers and recommended quants for a model family.           |
| `stack`        | A named, opinionated combination of products.                                |

Only the `workflow` skills exist today, so only they are listed. Skills of the other kinds appear in their own sections as they are published.

### Workflow skills

#### Decide

| Skill                                                 | Description                                                                                                            |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| [`choosing-llm-hosting`](skills/choosing-llm-hosting) | Decide where models should run (local, owned server, rented GPUs, serverless, APIs or hybrid) and record the decision. |

#### Run

| Skill                                                 | Description                                                                                                                                               |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`local-llms`](skills/local-llms)                     | Run models on a laptop or desktop with Ollama, LM Studio, llama.cpp or MLX.                                                                               |
| [`self-hosted-llms`](skills/self-hosted-llms)         | Serve models on your own NVIDIA Linux servers and DGX Spark as one authenticated endpoint (engines, llama-swap, LiteLLM, Cloudflare Tunnel or Tailscale). |
| [`cloud-llms`](skills/cloud-llms)                     | Run and consume models in the cloud: APIs, GPU VMs, serverless GPUs and managed endpoints, with budgets and teardown.                                     |
| [`self-hosted-genmedia`](skills/self-hosted-genmedia) | Self-host image, video, speech-to-text and text-to-speech servers next to your LLMs.                                                                      |

#### Connect

| Skill                               | Description                                                                                                               |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| [`llm-gateway`](skills/llm-gateway) | One OpenAI- and Anthropic-compatible gateway in front of many providers: keys, budgets, routing, fallbacks, API bridging. |
| [`llm-clients`](skills/llm-clients) | Connect coding agents, IDEs, chat UIs and SDKs to any OpenAI- or Anthropic-compatible endpoint.                           |

#### Improve

| Skill                                             | Description                                                                                  |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| [`llm-evals`](skills/llm-evals)                   | Evaluate models and option changes on your own tasks against any OpenAI-compatible endpoint. |
| [`model-quantization`](skills/model-quantization) | Produce and publish quantized checkpoints (GGUF, EXL3, FP8, NVFP4 and more).                 |
| [`fine-tuning-llms`](skills/fine-tuning-llms)     | Fine-tune open-weight models locally or on rented GPUs, then serve the result.               |

#### Operate

| Skill                                           | Description                                                                         |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| [`llm-observability`](skills/llm-observability) | Metrics, tracing, logging, cost tracking and alerting for LLM serving and LLM apps. |

## Roadmap

[`catalog.json`](catalog.json) lists every published and planned skill with its kind, category, status and build wave. Planned skills are not installable until they are published and listed above.

## Repository layout

```text
skills/<name>/
  SKILL.md        instructions the agent loads
  README.md       human overview: install, rules, references
  metadata.json   version, date, abstract, upstream references
  references/     detailed, version-stamped guides loaded on demand
  assets/         config and shell templates (some skills)
  scripts/        bench.sh, a shared curl + jq benchmark (some skills)
template/skill/   starting point for a new skill
tools/            new-skill.sh and tools/skeleton/<kind>/ scaffolds
scripts/          validate-skills.mjs and the git hook installer
catalog.json      every published and planned skill
docs/decisions/   architecture decision records
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `pnpm install`, then `pnpm verify` before opening a pull request. Agents follow [AGENTS.md](AGENTS.md). Report security issues as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
