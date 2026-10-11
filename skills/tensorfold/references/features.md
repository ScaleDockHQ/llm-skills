# TensorFold: features

> Verified against TensorFold v1.0.7, 2026-10-11

README, docs/api.md, docs/control.md, CHANGELOG, RELEASE notes

## Exact decoding

Every accepted draft equals the token the same engine produces with `"draft": false`; a resumed request equals fresh execution; each concurrent stream equals its solo run. The comparison fixes checkpoint, backend, settings and runtime; different quantizations or backends can differ. Drafts come from the checkpoint's MTP head (Nemotron) or a DFlash2 drafter (Qwen3.8-27B). `--no-drafts` and per-request `"draft": false` give the serial reference, useful for A/B quality gates.

## Prompt cache

A conversation's next turn resumes from kept prompt state. Nemotron on CUDA keeps state at 2,048-token chunk boundaries; prompts shorter than 4,096 tokens keep none; `--prompt-cache-gib` sizes it (16 GiB default on CUDA, inside the memory budget; 0 off). Replies equal the cache-off reply. `--learn` additionally persists shared prefixes (system prompt, tools) to disk on one Mac for GLM, Nemotron and Flash Next. Image and video prompts are not kept for prefix reuse in the recipes.

## Context compaction

Off by default; replies unchanged when off. `--compact-at auto|FRACTION` compacts a conversation that would overflow instead of refusing: system prompt and recent turns stay verbatim, tool calls stay paired with results, older turns become a memory note updated on each later compaction. The reply carries `tensorfold.compaction`, and every reply reports `context_window` and `context_used`. `--compact-keep` defaults to 20,000 tokens or a quarter of the window, whichever is smaller; `--compact-memory DIR` stores notes as Markdown.

## Vision

`--vision` enables `image_url` content parts on supported Qwen3.5/3.8 dense checkpoints (also in tool results). Unsupported image, audio, video and non-text output return HTTP 400. Details upstream: `docs/vision.md` (not read in full). Video and up to 50 images per request are **recipe** patches, not the release API.

## Structured output

`response_format`, `guided_json`, `guided_regex`, `guided_choice`, `guided_grammar`, `structured_outputs` are supported on the native server (the dual Flash Next recipe's engine refuses them with HTTP 400). Messages-API JSON schema output needs `pip install 'tensorfold[grammar]'` on the Python server.

## Living Weights (experimental)

`--slide` teaches a running Nemotron 3.5 Lightning new facts by writing them into the checkpoint's own shard files. Runs on Apple-silicon Macs and GB10; a folder taught on one serves on the other. **It rewrites the folder and nothing undoes a learned fact: always teach a copy.**

```bash
tensorfold pull TensorFold/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit
src=$(ls -d ~/.cache/huggingface/hub/models--TensorFold--NVIDIA-Nemotron-3.5-Lightning-30B-A3B-MLX-4bit/snapshots/* | head -1)
mkdir -p ~/models && cp -cRL "$src" ~/models/nemotron-living      # Linux: cp -RL
tensorfold serve ~/models/nemotron-living --slide
curl -N http://127.0.0.1:8080/v1/slide/learn -H 'Content-Type: application/json' -d '{"text": "I like blue."}'
```

`/slide` shows a 3D view; `GET /v1/slide/graph` returns the graph. Known issues (1.0.7): with thinking on only 4 of 6 test wordings recalled on a GB10; long documents are weak; facts from one document can answer each other's questions; a folder taught by 1.0.3 to 1.0.6 is refused by `--slide` (it still serves without it); issue #646 reports passing lessons overwriting facts that share a question template. Not for production data.

## macOS service and terminal dashboard

`tensorfold service install|start|stop|restart|status|doctor|logs|list|uninstall` manages a per-user macOS LaunchAgent (never root or sudo). Written against the Python server per `docs/control.md`; whether it fronts `tensorfold-native` in 1.0.7 was **not verified**. `tensorfold tui` is a keyboard dashboard (needs `prompt_toolkit`); remote URLs are monitor-only (`--token-env VAR` for a bearer key). Prefer a plain launchd/systemd unit around `tensorfold-native serve` if unsure.

## Other

`--chat-template FILE` overrides the template. `--loop-guard` closes short repeated reasoning cycles. Heat control for Linux (`TF_HEAT_HIGH`/`TF_HEAT_LOW`) pauses prompt chunks above a thermal band; tokens are unchanged. `tensorfold-native run --carveout` (Spark, experimental) puts Nemotron KV caches in display-controller reserved memory; see `docs/recipes/cuda.md`.
