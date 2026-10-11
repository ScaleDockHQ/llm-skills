# GGUF quantization: updating llama.cpp and redoing quants

> Verified against llama.cpp v0.6.0 and master b11556, 2026-10-11

llama.cpp publishes a build tag for nearly every merge (b11556, b11557 ... on 2026-10-11) and also a versioned release (v0.6.0 on 2026-10-05). The GGUF container is stable; quant layouts and metadata keys change slowly but converters change daily.

## When to update

- A new architecture is unsupported: `--print-supported-models` lacks it.
- A conversion fix for your model family landed (check llama.cpp issues and PRs for the architecture).
- You need a new type or flag (`llama-quantize --help` differs).

## Procedure

```bash
cd ~/src/llama.cpp
git fetch --tags && git describe --tags
git checkout <new-tag>
cmake --build build --config Release -j 8
. .venv/bin/activate && python3 -m pip install -r requirements.txt && pip install -U transformers
./build/bin/llama-quantize --help | head -20
```

- Keep the old build directory (or clone) until the new quants pass their checks.
- Existing GGUF files keep loading in newer llama.cpp; only requantize when a conversion bug or recipe change affects them.
- Requantize from a fresh 16-bit GGUF made by the new converter, not from the old file, when the architecture's converter changed (tensor layouts, template, MTP).
- An imatrix made against an older conversion is still usable if tensor names and shapes are unchanged; when in doubt regenerate it.
- Re-run the KLD table on the new build; do not compare numbers across builds without re-running.

## Roll back

`git checkout <old-tag> && cmake --build build --config Release -j 8` and reactivate the old venv requirements.
