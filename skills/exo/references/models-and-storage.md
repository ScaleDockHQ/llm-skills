# exo: models and storage

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: README (Custom Model Loading, Environment Variables), `docs/api.md`.

```bash
curl -fsS http://localhost:52415/models | jq 'length'
curl -fsS 'http://localhost:52415/models?status=downloaded'
curl -fsS 'http://localhost:52415/models/search?query=llama&limit=10'     # searches mlx-community on Hugging Face
```

## Custom models

`POST /models/add` with `{"model_id": "mlx-community/<name>"}` stores a custom model card under `~/.local/share/exo/custom_model_cards/` (Linux). Models that need `trust_remote_code` stay disabled unless explicitly enabled; leave that off unless you have read the code. Remove with `DELETE /models/custom/{model_id}`.

## Where weights go

Default `~/.exo/models` (macOS) or `~/.local/share/exo/models` (Linux). Add disks with `EXO_MODELS_DIRS=/Volumes/SSD/exo-models` (first with enough space is used) and shared read-only stores with `EXO_MODELS_READ_ONLY_DIRS=/mnt/nfs/models`. For air-gapped clusters stage weights first and set `EXO_OFFLINE=true`.

## Sizing

The model must fit in the combined memory of the placement; `memory_delta_by_node` in a preview shows the cost per node. Leave headroom for the KV cache and macOS. Image models need `EXO_ENABLE_IMAGE_MODELS=true`.
