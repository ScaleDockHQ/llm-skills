# faster-whisper: models and conversion

> Verified against faster-whisper v1.2.1 (faster_whisper/utils.py `_MODELS`, README) and Hugging Face model cards, 2026-10-11

## Built-in names

`WhisperModel("<name>")` maps these names to CTranslate2 repositories on the Hugging Face Hub and downloads them on first use:

| Name                                        | Hub repo                                       |
| ------------------------------------------- | ---------------------------------------------- |
| `tiny`, `base`, `small`, `medium` (+ `.en`) | `Systran/faster-whisper-<name>`                |
| `large-v1`, `large-v2`, `large-v3`          | `Systran/faster-whisper-<name>`                |
| `large`                                     | alias of `large-v3`                            |
| `distil-large-v2`                           | `Systran/faster-distil-whisper-large-v2`       |
| `distil-large-v3`                           | `Systran/faster-distil-whisper-large-v3`       |
| `distil-medium.en`, `distil-small.en`       | `Systran/faster-distil-whisper-<name>`         |
| `distil-large-v3.5`                         | `distil-whisper/distil-large-v3.5-ct2`         |
| `large-v3-turbo`, `turbo`                   | `mobiuslabsgmbh/faster-whisper-large-v3-turbo` |

List what the installed version knows: `python3 -c 'from faster_whisper.utils import available_models; print(available_models())'`. Any other CTranslate2-converted Whisper repo id also works (for example `deepdml/faster-whisper-large-v3-turbo-ct2`, which Speaches docs use).

## Choosing

- Accuracy first on a GPU: `large-v3`.
- Speed with near-large accuracy: `turbo` (large-v3-turbo). Per the vLLM docs for the same checkpoint family, turbo does not translate; use a non-turbo model for `task="translate"`.
- English only and small: `distil-small.en` or `distil-medium.en`; distil-large-v3 for English at higher accuracy. The README says distil-large-v3 is designed for faster-whisper's algorithm and shows `language="en", condition_on_previous_text=False`.
- CPU-only laptops: `small` or `distil-small.en` with `compute_type="int8"`.

Do not quote disk or VRAM sizes from memory; check the model card's file list (`curl -s https://huggingface.co/api/models/<repo> | jq '[.siblings[].rfilename]'`) and, for runtime memory, upstream's benchmark numbers in `performance-memory.md`.

## Licences

The library is MIT. Hub model cards read on 2026-10-11 list `mit` for the Systran repos, the turbo repo, `distil-whisper/distil-large-v3.5-ct2` and `deepdml/faster-whisper-large-v3-turbo-ct2`. `mobiuslabsgmbh/faster-whisper-large-v3-turbo` now redirects on the Hub to `dropbox-dash/faster-whisper-large-v3-turbo` (licence `mit`); the built-in `turbo` name should keep resolving through the redirect (not tested here; confirm with a download). Re-check cards when you pin a model.

## Convert your own Whisper

Any Whisper checkpoint compatible with Transformers (original OpenAI or a fine-tune) can be converted:

```bash
pip install 'transformers[torch]>=4.23'
ct2-transformers-converter --model openai/whisper-large-v3 --output_dir whisper-large-v3-ct2 \
  --copy_files tokenizer.json preprocessor_config.json --quantization float16
```

- `--model` takes a Hub name or a local directory.
- Without `--copy_files tokenizer.json` the tokenizer config is downloaded at load time.
- Load a converted directory with `WhisperModel("whisper-large-v3-ct2")`, or upload it to the Hub and load by repo id.
- The converter is part of CTranslate2; the conversion API is `ctranslate2.converters.TransformersConverter`.

## Cache and offline use

Models land in the Hugging Face cache (`HF_HOME`, default `~/.cache/huggingface`), or in `download_root` if set. For air-gapped hosts pre-download, copy the cache, and load with `local_files_only=True`. Private repos need `use_auth_token` or a CLI login (`huggingface-cli login`); never put the token in a script.
