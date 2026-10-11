# faster-whisper: performance and memory

> Verified against faster-whisper v1.2.1 README benchmarks and faster_whisper/transcribe.py, 2026-10-11

## Compute types

`compute_type` follows [CTranslate2 quantization](https://opennmt.net/CTranslate2/quantization.html). The accepted names include `default`, `float32`, `float16`, `bfloat16`, `int8`, `int8_float16`, `int8_bfloat16`, `int8_float32`, `int16` (the list Speaches validates against). Which ones work depends on device and hardware:

```bash
python3 -c 'import ctranslate2; print("cpu", ctranslate2.get_supported_compute_types("cpu")); print("cuda", ctranslate2.get_supported_compute_types("cuda"))'
```

Typical choices from the README: GPU `float16` or `int8_float16`; CPU `int8`. `default` keeps the type the model was stored in, converted if the device cannot run it.

## Upstream benchmarks

Time and memory to transcribe 13 minutes of audio, from the README (faster-whisper v1.1.0, CUDA 12.4, RTX 3070 Ti 8 GB, beam size 5). Treat as order-of-magnitude; hardware and versions differ.

| large-v2 on GPU               | Precision | Time  | VRAM    |
| ----------------------------- | --------- | ----- | ------- |
| faster-whisper                | fp16      | 1m03s | 4525 MB |
| faster-whisper `batch_size=8` | fp16      | 17s   | 6090 MB |
| faster-whisper                | int8      | 59s   | 2926 MB |
| faster-whisper `batch_size=8` | int8      | 16s   | 4500 MB |

| small on CPU (8 threads, i7-12700K) | Precision | Time  | RAM     |
| ----------------------------------- | --------- | ----- | ------- |
| faster-whisper                      | fp32      | 2m37s | 2257 MB |
| faster-whisper `batch_size=8`       | fp32      | 1m06s | 4230 MB |
| faster-whisper                      | int8      | 1m42s | 1477 MB |
| faster-whisper `batch_size=8`       | int8      | 51s   | 3608 MB |

Batching roughly cuts GPU time by 3 to 4 times for about 1.3 to 1.5 times the VRAM in these runs. Distil-large-v3 with `batch_size=16` took 25m50s versus 46m12s for Transformers on the long-audio benchmark.

## Knobs

- **Batching:** `BatchedInferencePipeline(model).transcribe(path, batch_size=16)`. Lower `batch_size` if CUDA runs out of memory. VAD is on by default in this path.
- **Threads (CPU):** `cpu_threads=N` or `OMP_NUM_THREADS=N python app.py`. A non-zero `cpu_threads` overrides the environment variable. When benchmarking, use the same thread count for every engine.
- **Parallel requests:** a single model object serves one decode at a time per worker. For a threaded service set `num_workers>1` (more memory) or run several processes; with several GPUs pass `device_index=[0, 1, ...]` and call `transcribe()` from several Python threads.
- **Smaller beam:** `beam_size=1` is the greedy setting openai-whisper uses; faster, a little less accurate.
- **Skip silence:** `vad_filter=True` removes silence and lowers hallucinations on pauses.
- **No timestamps:** `without_timestamps=True` decodes faster when you only need text.
- **Warm-up:** the first call pays model load and CUDA initialisation; benchmark the second call.

## Memory budgeting

VRAM use is weights plus batch activations plus CTranslate2 buffers. Start from the README table above for large-v2, scale down for smaller models, and measure with `nvidia-smi --query-gpu=memory.used --format=csv` while a batch runs. Co-residency with an LLM on one GPU is covered by `self-hosted-genmedia`.

## Fair comparisons

README guidance: use the same beam size (faster-whisper 5, openai-whisper 1), compare at similar word error rate because speed tracks transcript length, and set equal thread counts on CPU.
