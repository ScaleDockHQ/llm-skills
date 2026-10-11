# exo

> Verified against exo-explore/exo v1.0.71 (release 2026-04-23; main pyproject 0.3.70, Apache-2.0, not archived, pushed 2026-10-06; README and docs/api.md), 2026-10-11

Install later: the `exo` skill (not yet published) will own product depth. This is the stack-level view. exo connects devices into a cluster; each device runs an API and dashboard at `http://localhost:52415`. It uses MLX as the backend and MLX distributed for communication.

## Install options

- **macOS app:** requires macOS Tahoe 26.2 or later; `brew install --cask exo` or the `EXO-latest.dmg` from exolabs. The app asks to modify system settings and installs a Network profile (and a LaunchDaemon); uninstall from the menu bar icon (Advanced, Uninstall) or `sudo ./app/EXO/uninstall-exo.sh` from the source tree, then remove the Login Item manually.
- **From source (macOS):** prerequisites Xcode (Metal ToolChain), brew, `uv`, node, rust nightly, and a pinned `macmon` fork revision (Homebrew `macmon 0.6.1` crashes on Apple M5 per the README). Then:

```bash
git clone https://github.com/exo-explore/exo
cd exo/dashboard && npm install && npm run build && cd ..
uv sync --extra mlx
uv run exo                    # dashboard and API on http://localhost:52415
```

The project requires Python 3.13 (`requires-python = "==3.13.*"` in pyproject). With Nix: `nix run .#exo`.

- **Linux:** runs on CPU today (`uv sync --extra mlx-cpu`; CUDA extras `mlx-cuda12` or `mlx-cuda13` exist in pyproject); GPU support on Linux is described as under development. Not a Mac cluster member for GPU work.

## Configuration

| Variable                    | Meaning                                                                   |
| --------------------------- | ------------------------------------------------------------------------- |
| `EXO_DEFAULT_MODELS_DIR`    | Where models download (default `~/.exo/models` on macOS)                  |
| `EXO_MODELS_DIRS`           | Extra writable model dirs, colon-separated; first with free space is used |
| `EXO_MODELS_READ_ONLY_DIRS` | Read-only pre-downloaded model dirs (for example NFS)                     |
| `EXO_OFFLINE`               | `true` runs with local models only                                        |
| `EXO_LIBP2P_NAMESPACE`      | Cluster namespace; isolates clusters on one network                       |
| `EXO_ENABLE_IMAGE_MODELS`   | Image model support (default false)                                       |
| `EXO_FAST_SYNCH`            | Controls `MLX_METAL_FAST_SYNCH` for JACCL (default auto)                  |

Flags: `--no-worker` (coordinator only, no inference), `--legacy-daemon` (SysV-style daemon, Linux init scripts only; launchd and systemd run exo in the foreground).

Set a unique `EXO_LIBP2P_NAMESPACE` on every node of this cluster (or the app's Advanced setting) so a neighbour's exo cannot join yours.

## Use the API

Discovery is automatic. The documented flow for a model (replace the model id):

```bash
curl -s "http://localhost:52415/instance/previews?model_id=llama-3.2-1b" | jq -c '.previews[] | select(.error == null) | .instance' | head -n1   # pick a placement
curl -X POST http://localhost:52415/instance -H 'Content-Type: application/json' -d '{"instance": {...}}'   # paste the placement; asynchronous
curl -N "http://localhost:52415/instance/await?model_id=mlx-community/Llama-3.2-1B-Instruct-4bit"            # wait for type: ready
curl -N http://localhost:52415/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"mlx-community/Llama-3.2-1B-Instruct-4bit","messages":[{"role":"user","content":"hi"}],"stream":true}'
curl -X DELETE http://localhost:52415/instance/<instance_id>                                                  # id from /state
```

Other dialects: Claude Messages (`/v1/messages`), OpenAI Responses (`/v1/responses`), Ollama (`/ollama/api/chat`, `/ollama/api/tags`). Inspect with `GET /state`, `GET /models`, `GET /models?status=downloaded`, `GET /models/search?query=...`. Add a Hugging Face model with `POST /models/add`; models needing `trust_remote_code` are refused unless enabled explicitly (keep it off).

Benchmark placements: `uv run bench/exo_bench.py --model <short-id> --pp 128,512 --tg 128 --repeat 3 --json-out results.json` (filters `--sharding pipeline|tensor`, `--instance-meta ring|jaccl`, `--max-nodes N`).

## Pitfalls

- RDMA ports on different macOS versions may not discover each other (match versions exactly).
- A placement may be pipeline or tensor and ring or JACCL; read `sharding` and `instance_meta` in previews before creating one.
- The first model download is large and happens on each node that holds a shard; plan disk with `EXO_MODELS_DIRS`.
