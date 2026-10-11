# whisper.cpp: performance and memory

> Verified against whisper.cpp v1.9.5 (README backend sections, examples/cli, examples/server), 2026-10-11

No benchmarks were run for this file.

## Order of wins

1. **Use a GPU backend** that matches the hardware (`install.md`): Metal on Apple (on by default), `-DGGML_CUDA=1`, `-DGGML_VULKAN=1`, HIP, or CPU with BLAS/OpenVINO. Confirm in the log: the `system_info:` line and the `ggml_*_init` lines show which backend loaded. `-ng` forces CPU for comparison; `-dev N` or `WHISPER_ARG_DEVICE` picks the GPU.
2. **Pick the right model size** (`models.md`): `large-v3-turbo` is far cheaper than `large-v3`; quantize when memory is tight.
3. **Skip silence** with VAD (`cli.md`): only speech segments reach the decoder, which helps long recordings with gaps and reduces silence hallucinations.
4. **Keep the server resident** instead of launching `whisper-cli` per file: the model load dominates short clips.
5. **Core ML on Apple silicon** (below).

## Flash attention

On in the v1.9.5 source for both CLI and server (`-nfa` disables). The README help block still prints `false`, so rely on `-h` of your build.

## Core ML (Apple silicon)

The README says the encoder can run on the Apple Neural Engine for "more than x3 faster compared with CPU-only execution". Steps (README):

```bash
pip install ane_transformers openai-whisper coremltools          # Python 3.11 recommended
./models/generate-coreml-model.sh large-v3-turbo                 # writes models/ggml-large-v3-turbo-encoder.mlmodelc
cmake -B build -DWHISPER_COREML=1 && cmake --build build -j --config Release
```

Needs Xcode and the command-line tools; macOS 14 or newer is recommended because older versions may hallucinate. Keep the `.mlmodelc` folder next to the `.bin` with the matching name. The first run is slow while the ANE compiles it. `large-v3-turbo` generation was not run here (the README example is `base.en`).

## OpenVINO, NPUs and other backends

The README has sections for OpenVINO (Intel CPU and iGPU encoder), Ascend NPU, Moore Threads, BLAS (`-DGGML_BLAS=1`, also for POWER VSX) and a Vulkan section. They are build-time options with their own prerequisites; read the README section for your build and treat anything not listed in `install.md` as unverified here. The server accepts the OpenVINO encoder device through its flags (`whisper-server -h`).

## Threads and processors

`-t N` defaults to `min(4, hardware threads)`. More threads help CPU-only builds up to the number of physical cores and rarely matter on a GPU build. `-p N` sets the number of processors (default 1); leave it alone unless a benchmark on your hardware shows a gain.

## Memory

- README table: large about 3.9 GB with the 2.9 GiB model (`models.md`). Quantization shrinks the file and memory roughly in proportion.
- The server holds exactly one model and processes requests one at a time (`serve-configuration.md`), so its memory is stable. A second model means a second process.
- On a shared GPU box (llama-swap), a whisper-sized model fits next to an LLM. Prefer `ttl` unloading or a swap group when the LLM needs the whole GPU (`combos/llama-swap-litellm.md`; sizing with the `self-hosted-genmedia` memory planning reference).

## Measure

```bash
./build/bin/whisper-bench -m models/ggml-large-v3-turbo.bin -t 4
time ./build/bin/whisper-cli -m models/ggml-large-v3-turbo.bin -f samples/jfk.wav -np -nt
```

`whisper-cli` prints a `whisper_print_timings` block (load, mel, encode, decode, total) at the end; compare encode time across backends and models. The first run after a build, or with Core ML, includes one-time compile costs.
