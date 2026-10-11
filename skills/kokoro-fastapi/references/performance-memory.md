# Kokoro-FastAPI: performance and memory

> Verified against Kokoro-FastAPI v0.9.0 README (Performance & Operations) and docs/configuration.md, 2026-10-11

## What upstream reports

From the README, measured on Windows 11 with WSL2, an RTX 4060 Ti 16 GB, an 11th-gen i7 and 64 GB RAM, WAV output, a full novel as input:

- Real-time factor of roughly 35x to 100x (audio seconds per generation second).
- About 137.67 tokens per second on average (`cl100k_base`).
- First-token latency (streaming): about 300 ms on GPU at chunk size 400, about 3.5 s on an older i7 CPU at chunk size 200, under 1 s on an M3 Pro CPU at chunk size 200. Smaller chunks add intonation artifacts.

These are the maintainer's numbers on one machine; benchmark your own hardware with a representative text.

## Model size and memory

Kokoro-82M is an 82-million-parameter model, so weights are small. The README does not publish VRAM figures; measure with `nvidia-smi --query-gpu=memory.used --format=csv` before and after a long request, because the activation pool grows with load but plateaus (chunks cap at `ABSOLUTE_MAX_TOKENS=450`).

## Reclaiming VRAM

- `POST /dev/unload` frees the model; it reloads lazily on the next request. Needs `ALLOW_DEV_UNLOAD=true`; the route is unauthenticated, so keep the port private. `GET /dev/model` shows state and `POST /dev/reload` loads it.
- `MODEL_AUTO_UNLOAD_TIMEOUT_SECONDS=<n>` unloads after `n` idle seconds (default `0.0` disables). Use it to share a GPU with LLMs without an orchestrator; the cost is a reload on the next request.

## Concurrency

Inference is synchronous: one uvicorn process handles one generation at a time. `WEB_CONCURRENCY=N` starts N workers, each with its own model copy and memory. Queue clients or use a gateway with concurrency limits; many short requests are served better by more workers than a few long ones.

## Chunking

Text is split at sentence boundaries into chunks sized by `TARGET_MIN_TOKENS` (175), `TARGET_MAX_TOKENS` (250) and `ABSOLUTE_MAX_TOKENS` (450); the model limit is 510 tokens, and upstream notes that running chunks that long yields rushed speech and artifacts. Lower the targets for lower first-audio latency; raise them for smoother long-form narration. Very short alternating speaker turns slow multi-speaker generation because chunking requirements dominate (README: fewer than about two sentences per turn).

## Streaming

`stream` defaults to true on `/v1/audio/speech`: each chunk is a complete sentence. Use `response_format=pcm` for lowest-latency playback (raw 16-bit samples without headers; the README example plays 24000 Hz mono). `mp3` is the compatibility default.

## ROCm

MIOpen is disabled by default on ROCm because it compiles a kernel per tensor shape (5 to 60 s per new shape); upstream measured 2433 ms per generation with MIOpen versus 268 ms without on gfx1100 with ROCm 7.2. Keep `ENABLE_MIOPEN=false` unless your architecture has a prebaked kernel database.
