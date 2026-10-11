# Self-Hosted Generative Media Skill

An agent skill for running image, video, speech-to-text and text-to-speech servers on your own hardware, in the same LiteLLM → llama-swap stack that serves your LLMs. It helps the agent pick a server per modality, install it (x86 and NVIDIA DGX Spark), expose OpenAI-compatible `/v1/images/*` and `/v1/audio/*` routes, add entries to llama-swap and LiteLLM, plan memory next to resident LLMs, keep long generations alive past proxy timeouts, write smoke tests, and check model licenses. Built on the work of [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp), [ComfyUI](https://github.com/Comfy-Org/ComfyUI), [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [Speaches](https://github.com/speaches-ai/speaches), [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI), [llama-swap](https://github.com/mostlygeek/llama-swap), [LiteLLM](https://github.com/BerriAI/litellm) and [vLLM](https://github.com/vllm-project/vllm).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia
```

## Rules

- **Same endpoint, same rules.** Media routes get the same auth, loopback binding and monitoring as chat, and health checks must not trigger model loads.
- **Long jobs need a long path.** Cloudflare's proxy read timeout kills slow renders and cold swaps with a 524. Use async polling, a tailnet path, or preloading.
- **Plan memory with the LLMs, not after them.** Budget media models and LLMs together and choose co-resident or swap on purpose, especially on unified memory.
- **Check model licenses before serving.** Non-commercial, revenue-threshold and territory clauses differ per model and per component.
- **Weights on every node before the first swap.** A download inside a request meets every timeout and competes for memory.
- **Test each hop separately.** Upstream, then llama-swap, then LiteLLM, so a failure points to one config.

## References

- [`references/image-servers.md`](references/image-servers.md): sd-server endpoints, build, model files, async jobs, comparison with ComfyUI.
- [`references/comfyui.md`](references/comfyui.md): how ComfyUI plugs into this stack; depth in the `comfyui` skill.
- [`references/video.md`](references/video.md): open video models via ComfyUI native workflows, async job pattern, memory and time expectations.
- [`references/speech-to-text.md`](references/speech-to-text.md): Speaches, vLLM Whisper and whisper-server in the stack; OpenAI path mapping; LiteLLM entry; whisper.cpp depth in the `whisper-cpp` skill.
- [`references/text-to-speech.md`](references/text-to-speech.md): Kokoro-FastAPI and Speaches TTS; images, API, LiteLLM entry.
- [`references/stack-integration.md`](references/stack-integration.md): llama-swap entries and groups, `/comfyui/`, LiteLLM modes, end-to-end timeouts, auth.
- [`references/memory-planning.md`](references/memory-planning.md): memory budgets on discrete and unified GPUs, co-resident vs swap, capped scopes, hf-xet limits.
- [`references/licenses.md`](references/licenses.md): verified license terms for image, video and speech models and server software.
- [`assets/llama-swap-genmedia.yaml`](assets/llama-swap-genmedia.yaml): llama-swap entries and groups for media servers.
- [`assets/litellm-genmedia.yaml`](assets/litellm-genmedia.yaml): LiteLLM `model_list` entries for image and audio routes.

## Companion skills

- `comfyui`: ComfyUI install, API, custom nodes and memory (install: `npx skills add ScaleDockHQ/llms-skills --skill comfyui`)
- `whisper-cpp`: whisper.cpp build, models, server API and tuning (install: `npx skills add ScaleDockHQ/llms-skills --skill whisper-cpp`)
- `self-hosted-llms`: the LLM stack this plugs into, including the engine-sdcpp reference (install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`)
- `llm-gateway`: LiteLLM keys, budgets, routing and fallbacks (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`)
- `llm-clients`: connect apps and agents to the new endpoints (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`)
- `llm-observability`: logs, metrics and tracing (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`)
- `cloud-llms`: hosted APIs and rented GPUs when media load outgrows local hardware (install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`)
- `choosing-llm-hosting`: decide local vs self-hosted vs cloud (install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`)

## License

MIT
