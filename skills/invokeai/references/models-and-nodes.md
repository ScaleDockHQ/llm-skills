# InvokeAI: models, external providers and custom nodes

> Verified against InvokeAI v6.14.2 (docs concepts/models, features/External Models, features/Workflows custom-node-manager, config_default.py at tag v6.14.2), 2026-10-11

## Model Manager

Install models from the UI (first start shows a starter-models popup):

- **Starter Models**: curated list. Some carry licences that limit commercial use or public servers; the user must follow them.
- **URL or local path**: a direct download link or a path on disk. Sites that need a token use `remote_api_tokens`.
- **HuggingFace repo ID**, such as `XpucT/Deliberate`; add `:subfolder` for repos with several models (`monster-labs/control_v1p_sd15_qrcode_monster:v2`).
- **Scan Folder**: finds models in a folder and installs them all; untick **Inplace install** to copy them into the models directory instead of referencing them where they are.

Formats: `.ckpt`, `.safetensors` and diffusers folders; GGUF, FP8 and quantized variants exist per family (see the model family docs in the version you run). Model weights live under `<root>/models`; check free space first. The REST routes are under `/api/v2/models/` (see `/docs`).

Management features: edit a model's Source URL and defaults, multi-select **Delete** and **Reidentify** (reidentify re-derives configuration and can overwrite your custom settings), the **Missing Files** filter for orphaned records, and **Sync Models** for directories on disk with no record (deletion removes the whole directory; admins only in multi-user mode, API `/api/v2/models/sync/orphaned`). Export and import per-model settings as JSON (defaults, trigger phrases, name, cover image; no weights).

## Tokens and gated models

Gated Hugging Face models (for example Ideogram 4, non-commercial, with a baked-in safety filter that can false-positive) need an accepted licence and a token. Put the token in `invokeai.yaml` under `remote_api_tokens` with `url_regex: huggingface.co`, or provide it through `INVOKEAI_REMOTE_API_TOKENS` as JSON from a protected environment, and restart. Tokens are sent as Bearer headers to matching URLs. Never print them.

```yaml
remote_api_tokens:
  - url_regex: huggingface.co
    token: <from a 0600 file or secret manager>
```

Starter models and imports that execute code are guarded by picklescan; leave `unsafe_disable_picklescan` off.

## External providers (API-backed models)

Invoke can call hosted image APIs instead of running local weights: Google Gemini, OpenAI (GPT Image, DALL-E 3), BytePlus Seedream and Alibaba Cloud DashScope (Qwen Image, Wan T2I) in v6.14.2's docs. Keys go in `api_keys.yaml` next to `invokeai.yaml` (`external_openai_api_key`, `external_gemini_api_key`, `external_seedream_api_key`, `external_alibabacloud_api_key`, each with an optional `..._base_url`); restart afterwards and keep the file at mode `0600`, out of version control. Prompts and images leave the machine and are billed to the provider account, so get the user's approval; check the provider's pricing before large batches. Inpainting is not supported by any external provider in these docs. These are the only way to use Invoke on ARM64 CPU-only hosts productively.

## Custom nodes

The Custom Node Manager (UI) installs packs from a Git URL or a scanned `nodes/` folder and loads them into the running process immediately, no restart. Packs are **arbitrary Python with the server's privileges**; install only trusted authors and review the repository first. It does not run `pip install` for a pack's requirements; install those yourself inside the Invoke environment, then **Reload**. Uninstall removes the pack, its nodes and workflows imported from it. On a shared or exposed server limit what can run with `allow_nodes` or `deny_nodes` in `invokeai.yaml`.
