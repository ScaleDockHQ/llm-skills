# whisper.cpp: updating

> Verified against whisper.cpp v1.9.5 (GitHub releases and repo state), 2026-10-11

## What upstream publishes

`gh release list -R ggml-org/whisper.cpp` on 2026-10-11: `v1.9.5` (2026-10-06, marked Latest), `v1.9.4` (2026-09-11), `v1.9.3` (2026-08-20, flagged pre-release), and `bNNNN` pre-release tags such as `b5454` created next to each version. The repository was active (pushed 2026-10-11) and not archived. The `v1.9.5` release had **no downloadable assets** when checked, so build from source (`install.md`) or use a container image (amd64 only, see `install.md`).

## Update procedure

```bash
cd ~/src/whisper.cpp
git fetch --tags
git describe --tags                       # what you run now
git checkout v1.9.5                       # a release tag; avoid master for a service
cmake -B build -DGGML_CUDA=1              # re-use your backend flags
cmake --build build -j --config Release
./build/bin/whisper-cli --version         # confirm
```

1. Read the release notes (`gh release view <tag> -R ggml-org/whisper.cpp`) for flag renames before restarting the service. The README and the usage text can disagree (flash attention default, `quantize` vs `whisper-quantize`, see `serve-configuration.md`); trust `-h` of the binary you built.
2. Clean rebuild when the backend flags change: `rm -rf build` first.
3. Restart: `systemctl --user restart whisper-server`, or let llama-swap start the new binary on the next request.
4. Smoke test: `GET /health`, then `scripts/transcribe.sh samples/jfk.wav`.

## Models after an upgrade

ggml files are versioned by magic number and quantization version (`GGML_QNT_VERSION` in the quantizer). Files you downloaded earlier normally keep working across patch releases; if a load fails after an upgrade, re-download the model or re-run `whisper-quantize` from the full-precision file.

## Rollback

Keep the previous checkout or binary: `git checkout <previous-tag>`, rebuild, restart. Pin the tag in your notes or in a service wrapper so an unattended `git pull` does not move you to `master`.

## Docker

The registry tags `:main` and `:main-cuda` are moving targets. If you use them, pin a digest and re-check the platform (`install.md`).
