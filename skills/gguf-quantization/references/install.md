# GGUF quantization: install llama.cpp and the converter

> Verified against llama.cpp v0.6.0 and master b11556 (docs/build.md, tools/quantize/README.md, requirements.txt), 2026-10-11

Both halves must come from the same source tree: the Python converter (`convert_hf_to_gguf.py`) writes GGUF metadata that the compiled tools read. Build from a pinned tag, not a distro package.

## Build

```bash
git clone https://github.com/ggml-org/llama.cpp ~/src/llama.cpp
cd ~/src/llama.cpp
git tag --sort=-creatordate | head -5         # tags are b<N> builds; GitHub also shows a latest release
git checkout <tag>                            # pin; record it in the model card
```

Pick the backend. Quantization itself runs on CPU; only `llama-imatrix` and `llama-perplexity` benefit from a GPU.

| Backend     | Configure                                                 |
| ----------- | --------------------------------------------------------- |
| CPU only    | `cmake -B build`                                          |
| NVIDIA CUDA | `cmake -B build -DGGML_CUDA=ON`                           |
| Apple Metal | default on Apple Silicon (`-DGGML_METAL=OFF` disables it) |

Other backends (Vulkan, HIP, SYCL) are in upstream `docs/build.md`; use `llama-cpp` for their runtime tuning.

```bash
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release -j 8
ls build/bin/llama-quantize build/bin/llama-imatrix build/bin/llama-perplexity build/bin/llama-gguf-split
```

- A native CUDA build targets the GPU present. For a portable binary add `-DGGML_NATIVE=OFF` (see `docs/build.md` for the CUDA architecture list).
- On shared or small-RAM hosts cap memory: `systemd-run --user --scope -p MemoryMax=48G -p MemorySwapMax=0 -- cmake --build build --config Release -j 8` (Linux only).

## Converter environment

```bash
cd ~/src/llama.cpp
python3 -m venv .venv && . .venv/bin/activate
python3 -m pip install -r requirements.txt
# or: uv pip install -r requirements.txt --index-strategy unsafe-best-match
pip install -U transformers      # upstream: some models (e.g. Gemma 4) need transformers 5
```

The requirements install transformers 4 for compatibility; newer architectures may need `pip install -U transformers`. Conversion does not need a GPU.

## Discovery

```bash
./build/bin/llama-quantize --help | head -30
python convert_hf_to_gguf.py --help | head -40
python convert_hf_to_gguf.py --print-supported-models | head
git describe --tags
```

## No-build alternatives

- Prebuilt llama.cpp binaries are attached to GitHub releases (check the asset list for your platform); the Python converter comes from the source tree, so check out the matching tag.
- The [GGUF-my-repo](https://huggingface.co/spaces/ggml-org/gguf-my-repo) Space builds quants without setup; upstream says it syncs from llama.cpp `main` every 6 hours. Use it only when a hosted run is acceptable.
