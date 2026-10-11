# Build and package llamafiles

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

A llamafile is the runtime (APE, a polyglot shell script and executable) with weights and an `.args` file stored as uncompressed, page-aligned ZIP entries. `unzip -vl Model.llamafile` lists the contents.

## Package weights with zipalign

Inputs: the `llamafile` runtime (release file, or built from source), a GGUF, and a text `.args` file. `zipalign` is the project's own tool (release file `zipalign-0.10.6`), not the Android one.

`.args`: one argument per line. Embedded files use the `/zip/` prefix. A line `...` is replaced by the arguments the user passes at run time.

```text
-m
/zip/Qwen3-0.6B-Q8_0.gguf
-fa
on
--temp
0.6
-c
40960
--no-context-shift
...
```

```bash
cp llamafile Qwen3-0.6B-Q8.llamafile
./zipalign -j0 Qwen3-0.6B-Q8.llamafile Qwen3-0.6B-Q8_0.gguf .args     # -j0 stores uncompressed
chmod +x Qwen3-0.6B-Q8.llamafile
./Qwen3-0.6B-Q8.llamafile --server --port 8081
```

Server-by-default multimodal llamafile: add `--mmproj /zip/<proj>.gguf`, `--server`, `--host 0.0.0.0` (think before shipping that default), `-ngl 9999` and `--load-mode none` to `.args`, and embed the projector too.

Template: `templates/model.args`.

Windows runs only executables under 4 GB: for larger models ship the runtime and a separate GGUF. Do not default a distributed file to `--host 0.0.0.0` without an API key.

## Distribution

- Publish on Hugging Face and name the llamafile version or git revision in the commit message so others can verify provenance.
- If you change llama.cpp or Cosmopolitan sources, Apache 2.0 requires describing the changes; one way is embedding a notice with `zipalign`.
- Respect the model's own license; list it on the model card.
- The embedded executable is yours to vouch for: users must trust it as a program.

## Build from source

Requirements: GNU make (`gmake` on some systems), `sha256sum` (else `cc`), `wget` or `curl`, `unzip`; Windows also needs cosmos bash.

```bash
git clone https://github.com/mozilla-ai/llamafile && cd llamafile
make setup                             # initialises submodules, applies patches, downloads cosmocc 4.0.2 to .cosmocc
.cosmocc/4.0.2/bin/make -j"$(nproc)"   # macOS: -j"$(sysctl -n hw.physicalcpu)"
.cosmocc/4.0.2/bin/make check          # unit tests
sudo .cosmocc/4.0.2/bin/make install PREFIX=/usr/local
```

Outputs under `o/`: `o/llamafile/llamafile`, `o/third_party/zipalign/zipalign`, `o/llama.cpp/server/llama-server`, and for whisper `.cosmocc/4.0.2/bin/make -j8 o//whisperfile`. Always use cosmocc's make, not the system make. `make reset-repo` resets all submodules and removes local changes. `sudo make install` writes man pages for each program.

## GPU libraries

Use `llamafile/cuda.sh` (NVIDIA), `llamafile/rocm.sh` (AMD) or `llamafile/vulkan.sh` (any vendor, including NVIDIA and AMD), each needing its toolchain installed. They produce `ggml-cuda`, `ggml-rocm` and `ggml-vulkan` libraries. Place them next to the runtime (that location wins), in `~/.llamafile/v/<version>`, in `$HOME`, or bundle them into the llamafile with `zipalign`. Windows DLL builds (CUDA 12.9.1, HIP SDK 7.1.1, Vulkan SDK 1.4.341.1 per upstream) use the `.bat` scripts, with `--cublas` for a cuBLAS-linked CUDA library. Builds take a long time and need large disks; ask before starting.
