# Kokoro-FastAPI: configuration

> Verified against Kokoro-FastAPI v0.9.0 docs/configuration.md (last updated 2026-08-11) and `api/src/core/config.py`, 2026-10-11

Names are the `Settings` field names in upper case. Set them with `-e VAR=value`, a Compose `environment:` block, or a repo-root `.env` (Compose `environment:` wins over `env_file`). Unknown keys in `.env` are ignored. `PYTHONPATH`, `DOWNLOAD_MODEL`, `API_LOG_LEVEL` and `USE_GPU` are pinned in the shipped compose files, so setting them in `.env` does nothing there. `API_LOG_LEVEL`, `WEB_CONCURRENCY` and `DOWNLOAD_MODEL` are process-only (env vars, not `.env`).

## API

| Variable          | Default           | Notes                                                                                                                              |
| ----------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `HOST`, `PORT`    | `0.0.0.0`, `8880` | bind inside the container; host exposure is the publish flag                                                                       |
| `API_LOG_LEVEL`   | `DEBUG`           | loguru level; set `WARNING` or `INFO` in production                                                                                |
| `WEB_CONCURRENCY` | `1`               | uvicorn workers. Inference is synchronous, so one process serves one request at a time; each extra worker loads its own model copy |

## Model and device

| Variable         | Default                    | Notes                                              |
| ---------------- | -------------------------- | -------------------------------------------------- |
| `USE_GPU`        | `true`                     | use the GPU if available                           |
| `DEVICE_TYPE`    | auto                       | force `cuda`, `mps` or `cpu`                       |
| `MODEL_DIR`      | `/app/api/src/models`      | container path to weights                          |
| `VOICES_DIR`     | `/app/api/src/voices/v1_0` | container path to voice packs                      |
| `MODEL_REPO_ID`  | `hexgrad/Kokoro-82M`       | fallback download source when `MODEL_DIR` is empty |
| `DOWNLOAD_MODEL` | `true`                     | fetch weights at image build and container start   |

## Voices

| Variable                     | Default    | Notes                                                                                            |
| ---------------------------- | ---------- | ------------------------------------------------------------------------------------------------ |
| `DEFAULT_VOICE`              | `af_heart` | used when a request omits `voice`; also warms the model at startup                               |
| `DEFAULT_VOICE_CODE`         | unset      | overrides the language code from the voice's first letter for every speaker                      |
| `VOICE_WEIGHT_NORMALIZATION` | `true`     | rescale blend weights to sum to 1                                                                |
| `ALLOW_LOCAL_VOICE_SAVING`   | `false`    | needed for `/v1/audio/voices/combine` (403 otherwise) and `/dev/tune` `save_voice`               |
| `ENABLE_VOICE_TAGS`          | `true`     | kill switch for `[voice:]` parsing and `/dev/dialogue`; set `false` when proxying untrusted text |

## Text processing

| Variable                      | Default   | Notes                                                              |
| ----------------------------- | --------- | ------------------------------------------------------------------ |
| `TARGET_MIN_TOKENS`           | `175`     | chunker aims for at least this many tokens                         |
| `TARGET_MAX_TOKENS`           | `250`     | aims for at most                                                   |
| `ABSOLUTE_MAX_TOKENS`         | `450`     | hard ceiling per chunk; the model limit is 510                     |
| `ENABLE_SSML`                 | `true`    | kill switch; SSML routes and `ssml: true` return 403 when off      |
| `SSML_MAX_DEPTH`              | `10`      | deeper nesting is a 400                                            |
| `MAX_PAUSE_DURATION_S`        | `60.0`    | cap per `[pause:Ns]` or `<break>`                                  |
| `MAX_TOTAL_PAUSE_S`           | `300.0`   | total silence per request, over it is a 400                        |
| `MAX_INPUT_LENGTH`            | `1000000` | characters per request, over it is a 400; lower it on shared hosts |
| `ADVANCED_TEXT_NORMALIZATION` | `true`    | number, URL and email expansion before phonemizing (English only)  |

## Audio

`DEFAULT_VOLUME_MULTIPLIER` (`1.0`), `GAP_TRIM_MS` (`1`), `DYNAMIC_GAP_TRIM_PADDING_MS` (`410`), `DYNAMIC_GAP_TRIM_PADDING_CHAR_MULTIPLIER` (dict, set in `.env`).

## Web, CORS, temp files

| Variable                                                               | Default          | Notes                                                        |
| ---------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------ |
| `ENABLE_WEB_PLAYER`, `WEB_PLAYER_PATH`                                 | `true`, `web`    | the browser UI at `/web`                                     |
| `CORS_ENABLED`, `CORS_ORIGINS`                                         | `true`, `["*"]`  | narrow the origins if the port is reachable beyond localhost |
| `TEMP_FILE_DIR`                                                        | `api/temp_files` | files for `return_download_link`                             |
| `MAX_TEMP_DIR_SIZE_MB`, `MAX_TEMP_DIR_AGE_HOURS`, `MAX_TEMP_DIR_COUNT` | `2048`, `1`, `3` | pruning limits                                               |

## Operational and risky routes (all off by default)

| Variable                            | Default | Enables                                                               |
| ----------------------------------- | ------- | --------------------------------------------------------------------- |
| `ENABLE_DEBUG_ENDPOINTS`            | `false` | `/debug/*` host and process introspection                             |
| `ALLOW_DEV_UNLOAD`                  | `false` | `/dev/model`, `POST /dev/unload`, `POST /dev/reload`                  |
| `ENABLE_INNO_TUNER`                 | `false` | `POST /dev/tune` and the web player tuner tab                         |
| `MODEL_AUTO_UNLOAD_TIMEOUT_SECONDS` | `0.0`   | idle seconds before the model leaves VRAM; `0` disables               |
| `ENABLE_MIOPEN`                     | `false` | ROCm only; MIOpen compiles a kernel per tensor shape and slows Kokoro |

Leave them off unless needed. With no authentication, enabling them exposes them to anyone who can reach the port.

## Text normalization (per request)

`normalization_options` on the speech endpoints: `normalize` (`true`), `url_normalization`, `email_normalization`, `phone_normalization`, `caps_normalization`, `optional_pluralization_normalization`, `replace_remaining_symbols` (all `true`), `unit_normalization` (`false`), `remove_emoji` (`false`). Only English has a normalizer; `remove_emoji` works for every language.

```json
{
  "input": "10KB at user@example.com",
  "voice": "af_heart",
  "normalization_options": { "unit_normalization": true, "remove_emoji": true }
}
```

## Logging

`docker run -e API_LOG_LEVEL=WARNING ...`, or `export API_LOG_LEVEL=WARNING` before `./start-*.sh`.
