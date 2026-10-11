# whisper.cpp: install and build

> Verified against whisper.cpp v1.9.5 (README, CMakeLists.txt, examples/*/CMakeLists.txt, models/download-ggml-model.sh), ggml v0.26.0 and the ghcr.io registry manifests, 2026-10-11

Upstream: [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT, not archived, last push 2026-10-11). Latest tagged release v1.9.5 (2026-10-06, "maintenance release", updates to ggml v0.26.0). Nightly builds are tagged `bNNNN` (b5454 on 2026-10-06). Release assets were not inspected; this skill builds from source.

## Build from source

```bash
git clone https://github.com/ggml-org/whisper.cpp ~/whisper.cpp && cd ~/whisper.cpp
git checkout v1.9.5                          # a release tag; skip for the development line
cmake -B build                               # CPU (plus Metal on Apple, which is on by default there)
cmake --build build -j --config Release
./build/bin/whisper-cli -h | head -3
```

`CMAKE_BUILD_TYPE` defaults to Release for single-config generators. Examples and the server build by default when whisper.cpp is the top-level project (`WHISPER_BUILD_EXAMPLES`, `WHISPER_BUILD_SERVER`).

### Backend flags (README sections, same CMake commands)

| Hardware                         | Configure line                                            | Notes                                                                                                                                                  |
| -------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| CPU only                         | `cmake -B build`                                          | AVX/NEON picked by the build; `-t N` sets threads at run time                                                                                          |
| Apple silicon GPU                | `cmake -B build`                                          | `GGML_METAL` defaults to ON when building for Apple                                                                                                    |
| Apple Neural Engine (encoder)    | `cmake -B build -DWHISPER_COREML=1`                       | needs a generated `*-encoder.mlmodelc`; see `performance-memory.md`                                                                                    |
| NVIDIA                           | `cmake -B build -DGGML_CUDA=1`                            | install CUDA first. README for RTX 5000 series adds `-DCMAKE_CUDA_ARCHITECTURES="86"`; use the architecture that matches your GPU                      |
| Vulkan (cross-vendor)            | `cmake -B build -DGGML_VULKAN=1`                          | needs a Vulkan driver                                                                                                                                  |
| AMD ROCm                         | `cmake -B build -DGGML_HIP=1 -DAMDGPU_TARGETS="gfx1201"`  | replace with `rocminfo \| grep gfx`; several: `"gfx1100;gfx1201"`                                                                                      |
| OpenVINO (Intel CPU/GPU encoder) | `cmake -B build -DWHISPER_OPENVINO=1`                     | source the OpenVINO `setupvars.sh` first; README recommends OpenVINO 2026.3.0; generate the encoder model with `models/convert-whisper-to-openvino.py` |
| AMD Ryzen AI NPU                 | `cmake -B build -DWHISPER_VITISAI=1`                      | Windows 11 or Ubuntu 24.04; needs XRT and FlexML runtimes and `models/download-vitisai-model.sh <model>`                                               |
| OpenBLAS CPU                     | `cmake -B build -DGGML_BLAS=1`                            | encoder speed-up on CPU; also the POWER VSX path                                                                                                       |
| Others                           | `-DGGML_CANN=1` (Ascend), `-DGGML_MUSA=1` (Moore Threads) | per README sections                                                                                                                                    |

Build only what you need: add `--target whisper-server` (or `whisper-cli`) to `cmake --build` for a faster build.

**Capped builds on shared or unified-memory hosts.** A CUDA build can use a lot of RAM at `-j`. Limit it:

```bash
systemd-run --user --scope -p MemoryMax=16G -p MemorySwapMax=0 -- \
  bash -c 'cmake -B build -DGGML_CUDA=1 && cmake --build build -j --config Release'
```

### Binaries produced (`build/bin/`)

Target names read from `examples/*/CMakeLists.txt` at v1.9.5:

| Binary                              | Purpose                                                         |
| ----------------------------------- | --------------------------------------------------------------- |
| `whisper-cli`                       | transcribe files (`cli.md`)                                     |
| `whisper-server`                    | HTTP server (`serve-configuration.md`)                          |
| `whisper-quantize`                  | quantize ggml models (`models.md`)                              |
| `whisper-bench`                     | benchmark (`-m`, `-t`, `-w`, `-ng`, `-fa`/`-nfa`)               |
| `whisper-vad-speech-segments`       | print speech segments with a VAD model                          |
| `parakeet-cli`                      | NVIDIA Parakeet TDT models (separate model family; `models.md`) |
| `whisper-stream`, `whisper-command` | microphone examples; only built with `-DWHISPER_SDL2=ON`        |

The old names `main`, `bench`, `stream`, `command` still exist as deprecation stubs that point to the `whisper-*` replacements (`examples/deprecation-warning`). The README's quantization section still shows `./build/bin/quantize`; the real target is `whisper-quantize` (check `ls build/bin`).

## FFmpeg

`ffmpeg` is a runtime tool for `whisper-server --convert` and the usual way to make 16 kHz WAV (`ffmpeg -i input.mp3 -ar 16000 -ac 1 -c:a pcm_s16le output.wav`, README). Separately, building with `-DWHISPER_COMMON_FFMPEG=yes` makes the examples decode more formats natively (needs `libavcodec`, `libavformat`, `libavutil` dev packages). By default the examples decode with miniaudio.

## Docker images

README lists `ghcr.io/ggml-org/whisper.cpp:main` (with `curl` and `ffmpeg`; README says `linux/amd64` and `linux/arm64`), `:main-cuda`, `:main-musa`, `:main-vulkan` (README: `linux/amd64`), and mentions `main-intel`, `main-rocm` and `cublas` in a usage comment.

**Registry check on 2026-10-11:** the manifests for `main`, `main-cuda` and `main-vulkan` listed **only `linux/amd64`**, so the README's arm64 claim for `main` did not hold. On arm64 (DGX Spark, Raspberry Pi, Graviton), build from source. Re-check with `docker manifest inspect ghcr.io/ggml-org/whisper.cpp:main`.

```bash
IMAGE=ghcr.io/ggml-org/whisper.cpp:main-cuda
MODELS=/srv/models/whisper
docker run --rm -v "$MODELS":/models $IMAGE download-ggml-model.sh large-v3-turbo /models
docker run -d --name whisper --gpus all -p 127.0.0.1:8080:8080 -v "$MODELS":/models $IMAGE \
  whisper-server --host 0.0.0.0 -m /models/ggml-large-v3-turbo.bin -l auto
```

Inside a container the server must listen on `0.0.0.0`; publish it with `127.0.0.1:` on the host. (`--gpus all` needs the NVIDIA container toolkit; the README's GPU example for Vulkan uses `--device /dev/dri`.) Pin images by digest in production because `main` moves with every commit.

## Download a model

```bash
sh ./models/download-ggml-model.sh large-v3-turbo          # writes models/ggml-large-v3-turbo.bin
sh ./models/download-ggml-model.sh large-v3-turbo /srv/models/whisper   # second argument: target directory (as the Docker example uses)
sh ./models/download-ggml-model.sh                          # no argument: lists the available names
```

The script downloads from `https://huggingface.co/ggerganov/whisper.cpp` (the `tdrz` models come from `akashmjn/tinydiarize-whisper.cpp`), using `wget2`, `curl` or `wget`, and sends `Authorization: Bearer $HF_TOKEN` when `HF_TOKEN` is set. Check free disk first (`models.md` for sizes).

## Verify

```bash
./build/bin/whisper-cli -m models/ggml-base.en.bin -f samples/jfk.wav -nt 2>&1 | tail -3
./build/bin/whisper-cli -m models/ggml-base.en.bin -f samples/jfk.wav 2>&1 | grep -i -E "system_info|backend|gpu|metal|cuda" | head
```

The `system_info` line lists compiled features (`AVX`, `NEON`, `COREML`, `OPENVINO`, ...); GPU backend messages appear in the load log. If you built for a GPU but see none, see `troubleshooting.md`.
