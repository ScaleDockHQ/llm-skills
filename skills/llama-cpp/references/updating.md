# llama.cpp: updating and version pinning

> Verified against llama.cpp b11556 (master) and v0.6.0 (docs/install.md, docs/docker.md, release notes), 2026-10-11

Builds are published several times a day as `bNNNN` tags; `vX.Y.Z` tags such as v0.6.0 are named release markers whose notes summarise a period of work (v0.6.0's assets list contains no binaries, so install from the `bNNNN` builds or a package manager). Update on purpose, not constantly: new model architectures need new builds, but templates, parsers and defaults change between builds.

## What changed recently (breaking or surprising)

- Default port: `--port` default is **9931** from b11521 (earlier builds and the v0.6.0 docs use 8080). Pass `--port` explicitly everywhere.
- Speculative decoding flags were reorganised: `--draft`, `--draft-max`, `--draft-min`, `--spec-ngram-size-n/m` and `--spec-ngram-min-hits` are removed (help text says so); use `--spec-type` plus `--spec-draft-n-max`, `--spec-draft-model`, `--spec-ngram-*`.
- `--jinja` is on by default; `-fa` takes `on|off|auto`; GPU layers accept `auto|all`; `--fit` auto-adjusts unset arguments (these appear in the master help; confirm on your build).
- `llama-cli` is for conversation; docs now point non-interactive raw-prompt use to `llama-completion` (Docker `light` images ship both).
- Router mode (`--models-dir`, `--models-preset`, `--models-max`) and `--sleep-idle-seconds` exist on current builds; older builds ignore or reject them.
- The unified `llama` binary (llama.app installer) is a newer packaging; `llama-server` remains the stable name for scripts.

Read the release notes before a jump: `gh release view v0.6.0 --repo ggml-org/llama.cpp` or `gh release list --repo ggml-org/llama.cpp --limit 5`.

## Update by install route

| Route                    | Update                                                                                                                                                                                            | Roll back                                                                                                        |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Homebrew                 | `brew update && brew upgrade llama.cpp`                                                                                                                                                           | `brew pin llama.cpp` to hold; older versions need a tap formula or archive                                       |
| Winget                   | `winget upgrade llama.cpp`                                                                                                                                                                        | `winget install llama.cpp --version <v>` (versions are the build tags; check `winget show llama.cpp --versions`) |
| conda-forge              | `conda update -c conda-forge llama.cpp`                                                                                                                                                           | `conda install llama.cpp=<version>`                                                                              |
| Nix / MacPorts           | Update nixpkgs or run `sudo port upgrade llama.cpp`                                                                                                                                               | Nix generations                                                                                                  |
| llama.app installer      | Re-run `curl -LsSf https://llama.app/install.sh \| sh`; the `llama` binary may also self-update (**unverified**: check `llama --help`)                                                            | Keep the old binary renamed first                                                                                |
| Release archive          | Download the new `bNNNN` archive into a new directory, repoint a `current` symlink                                                                                                                | Repoint the symlink                                                                                              |
| Docker                   | `docker pull ghcr.io/ggml-org/llama.cpp:server-cuda13`, record the digest (`docker image inspect --format '{{index .RepoDigests 0}}'`), recreate the container                                    | Run the previous digest (`image@sha256:...`)                                                                     |
| Source                   | `git fetch --tags && git checkout bNNNN && cmake --build build --config Release -j` (re-run `cmake -B build ...` if backend flags changed; delete `build/CMakeCache.txt` after toolchain changes) | `git checkout <old tag>` and rebuild                                                                             |
| llama-swap unified image | Pull the new `ghcr.io/mostlygeek/llama-swap:unified-*` image                                                                                                                                      | Previous digest                                                                                                  |

Pin explicitly in production: a digest, a build tag, or a package version. Docker tags (`server`, `server-cuda13`) move with every build.

## Safe update procedure

1. Record the current build: `llama-server --version`, the model files and your flag set.
2. Read the release notes between the two builds for flag renames and model-support changes.
3. Update on a staging port (or a second container) first, with the same flags and model.
4. Smoke test (below). Compare `llama-bench` numbers against the previous build.
5. Switch traffic (restart the service or router child; model loads take seconds to minutes). Keep the old binary or digest for rollback.

## Smoke test after any update

```bash
B=http://127.0.0.1:9931
curl -fs $B/health && curl -s $B/v1/models | jq '.data[].id'
curl -s $B/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"local-model","messages":[{"role":"user","content":"Say OK"}],"max_tokens":8}' | jq -r '.choices[0].message.content'
# tool call and reasoning, because templates and parsers change often
curl -s $B/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"local-model","messages":[{"role":"user","content":"Weather in Paris?"}],"tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}}}}}]}' | jq '.choices[0].message | {tool_calls, reasoning_content}'
curl -s $B/props | jq '.build_info'
```

Check the startup log for the expected backend and offloaded layers, and that `Chat format:` for tool models is not unexpectedly `Generic`.

## Updating models

Re-download with the same `-hf` tag to pick up a re-quantized repo (the cache keeps old files; clear with care, `LLAMA_CACHE`). Quants made with an older build still load; re-quantize only for quality reasons. A model that needs a newer architecture fails with `unknown model architecture`: update the binary, not the model.

## Updating when serving through llama-swap

Update the llama.cpp image or binary first, then restart llama-swap (or let `ttl` expire and unload each model so the next request starts the new binary). If the unified image is used, llama.cpp and llama-swap update together.

## Sources

- https://github.com/ggml-org/llama.cpp/releases
- https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/docker.md
