# Xinference updating

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

Major versions bring
breaking changes, so read the notes: `gh release view -R xorbits-ai/inference` (repo is `xorbitsai/inference`)
or https://github.com/xorbitsai/inference/releases.

## Procedure

1. Record the current state: `xinference --version`, `xinference list`, launch commands, `pip freeze | grep -E
   'xinference|xoscar|xllamacpp'`. Back up `XINFERENCE_HOME/auth/` and `launch_history.db`.
2. Read release notes since your version. Check engine minimums you rely on (vLLM, SGLang, mlx-lm).
3. Upgrade the same way you installed:
   - One-command installer: re-run it (pin `XINFERENCE_VERSION` each time). It prepares the candidate,
     backs up the old environment, switches and waits for readiness; service upgrades roll back on failure.
     Stop a foreground server first. `uv tool upgrade xinference` is not the supported path for this install.
   - pip: `pip install "xinference==X.Y.Z"` in the same venv, on supervisor and every worker.
   - Docker or compose: change the image tag (`xprobe/xinference:vX.Y.Z`) in one place; for offline setups also
     the `xinference-pypiserver` tag to the same release; `docker compose pull && docker compose up -d`.
   - Helm: `helm repo update xinference` then `helm upgrade` (list versions with `helm search repo xinference/xinference --devel --versions`).
4. Models that were running are not restored across a restart: relaunch them (or use autostart). Virtualenvs
   rebuild when a model's dependency list changes.
5. Smoke test: `/status`, `xinference list`, chat, stream, tools, embeddings you use. Keep the previous
   environment, image or chart revision for rollback; downgrade with `XINFERENCE_VERSION` or the old tag.
6. Client libraries: `pip install xinference-client==<new version>`.

## Notable breaking changes

- **v4.0.0:** adds Xavier for vLLM, SGLang and MLX, cross-engine P/D, `enable_weight_cache` and
  `xinference reload`, distributed vLLM V1 through xoscar (no Ray), `/v1/responses`, installer-managed
  services. vLLM Xavier P/D defaults to GPU-to-GPU handoff and needs `xoscar[nixl]>=0.11.1` and a real host
  address.
- **v3.5:** media fetch hardening (private addresses and local paths rejected by default); launch
  recommendations; model request logging.
- **v3.0:** authentication on by default (the `--auth-config` JSON system is removed); slim GPU image on
  CUDA 13.0 with engines installed per model; auto-selected xllamacpp GPU wheels; the web UI is served by the
  server (`XINFERENCE_FRONTEND_ENDPOINT` removed).
- **v1.6.0:** `llama-cpp-python` removed (xllamacpp replaces it).
- Permission names `models:start/stop/add/unregister` were replaced by `models:write` and
  `models:register` (old names still map, deprecated).
