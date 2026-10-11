# Kokoro-FastAPI: HTTP API

> Verified against Kokoro-FastAPI v0.9.0 (README, `api/src/routers/*.py`, `structures/schemas.py`), 2026-10-11

Base `B=http://127.0.0.1:8880`. There is no authentication. Interactive docs: `$B/docs`. Web player: `$B/web`.

## Routes

| Method and path                                      | Purpose                                                                                              |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `GET /health`                                        | `{"status":"healthy"}`                                                                               |
| `POST /v1/audio/speech`                              | OpenAI-compatible synthesis, returns audio bytes (streamed by default)                               |
| `GET /v1/audio/voices`                               | `{"voices":[{"id","name",...}],"default_voice":...}`; `?legacy=true` gives plain strings             |
| `POST /v1/audio/voices/combine`                      | download a blended voice as `.pt`; 403 unless `ALLOW_LOCAL_VOICE_SAVING=true`                        |
| `GET /v1/models`, `/v1/models/{model}`               | fixed list: `tts-1`, `tts-1-hd`, `kokoro`, `gpt-4o-mini-tts` (the single-model route omits the last) |
| `GET /v1/download/{filename}`                        | fetch a file made with `return_download_link`                                                        |
| `POST /dev/captioned_speech`                         | audio plus word-level timestamps                                                                     |
| `POST /dev/phonemize`, `/dev/generate_from_phonemes` | text to phonemes, phonemes to audio                                                                  |
| `POST /dev/dialogue`                                 | structured multi-speaker turns                                                                       |
| `POST /dev/ssml`, `GET /dev/ssml`                    | SSML translation and capability tables                                                               |
| `POST /dev/tune`                                     | voice tuning from a reference clip (needs `ENABLE_INNO_TUNER=true`)                                  |
| `/dev/model`, `/dev/unload`, `/dev/reload`           | model state (needs `ALLOW_DEV_UNLOAD=true`)                                                          |
| `/debug/*`                                           | introspection (needs `ENABLE_DEBUG_ENDPOINTS=true`)                                                  |

## Speech request

```bash
curl -sS "$B/v1/audio/speech" -H 'Content-Type: application/json' \
  -d '{"model":"kokoro","input":"Hello from the self-hosted stack.","voice":"af_heart","response_format":"mp3","speed":1.0}' \
  -o hello.mp3 && file hello.mp3
```

Body fields from `OpenAISpeechRequest`:

| Field                   | Default         | Notes                                                                                   |
| ----------------------- | --------------- | --------------------------------------------------------------------------------------- |
| `model`                 | `kokoro`        | `tts-1`, `tts-1-hd`, `kokoro` are accepted                                              |
| `input`                 | required        | text, with inline tags below                                                            |
| `voice`                 | `DEFAULT_VOICE` | single voice, blend `af_bella(2)+af_sky(1)`, alias, or a saved voice name               |
| `response_format`       | `mp3`           | `mp3`, `opus`, `aac`, `flac`, `wav`, `pcm` (raw 16-bit, 24 kHz in the README example)   |
| `speed`                 | `1.0`           | speaking rate                                                                           |
| `stream`                | `true`          | streams chunks of whole sentences                                                       |
| `lang_code`             | from voice name | overrides the language pipeline                                                         |
| `volume_multiplier`     | `1.0`           | output gain                                                                             |
| `normalization_options` | defaults        | see `configuration.md`                                                                  |
| `return_download_link`  | `false`         | adds `X-Download-Path`; with `return_timing` also `X-Timing-Path` (chunk-level sidecar) |
| `allow_voice_tags`      | `false`         | enables `[voice:]` and `[rate:]` tags                                                   |
| `voice_aliases`         | none            | map of short names to voices or `{"voice":...,"rate":...}`                              |
| `ssml`                  | `false`         | translate SSML first; requires `allow_voice_tags: true`                                 |

OpenAI SDK, passing the extras in `extra_body`:

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:8880/v1", api_key="not-needed")   # any placeholder; no auth
with client.audio.speech.with_streaming_response.create(
    model="kokoro", voice="af_sky+af_bella", input="Hello world!"
) as r:
    r.stream_to_file("output.mp3")
```

## Voices

```bash
curl -sS "$B/v1/audio/voices" | jq -r '.voices[].id'
```

- Blend with weights: `af_bella(2)+af_sky(1)` gives roughly 67% and 33%; weights are normalized when `VOICE_WEIGHT_NORMALIZATION=true`. Works anywhere `voice` is accepted.
- Saved or downloaded blends: `POST /v1/audio/voices/combine` with a JSON string body (`"af_bella(2)+af_sky(1)"`) returns a `.pt` file; place such files in `VOICES_DIR` and use the file's base name as the voice. Needs `ALLOW_LOCAL_VOICE_SAVING=true`.
- Language families by prefix: supported languages are English (US and GB), Spanish, French, Hindi, Italian, Japanese, Brazilian Portuguese and Mandarin Chinese.

## Inline text control

Parsed server side anywhere `input` is accepted:

- `[pause:1.5s]` inserts silence (exact form; `[pause=1.5]` is read aloud). Capped by `MAX_PAUSE_DURATION_S` and `MAX_TOTAL_PAUSE_S`.
- Pronunciation override: put the word in square brackets followed by the IPA in parentheses between slashes (upstream example: Worcester with the IPA wˈʊstər); English only; find IPA with `/dev/phonemize`.
- `[voice:am_michael]` switches speaker; needs `allow_voice_tags: true` and `ENABLE_VOICE_TAGS`. Unknown values are a 400.
- `[rate:1.5]` scales pace (0.25 to 4.0, on top of `speed`) until the next rate tag or voice change; `[rate:1.0]` reverts.

Aliases keep tags short:

```bash
curl -sS "$B/v1/audio/speech" -H 'Content-Type: application/json' -d '{
  "model":"kokoro","voice":"narrator","response_format":"mp3",
  "input":"[voice:narrator] Once upon a time. [voice:villain] Never!",
  "allow_voice_tags":true,
  "voice_aliases":{"narrator":"af_bella(2)+af_sky","villain":"am_michael"}
}' -o aliased.mp3
```

`POST /dev/dialogue` takes `{"turns":[{"voice","text"}],"pause_between_turns":0.4,"response_format":"mp3"}`; consecutive turns with the same voice merge. Each speaker keeps its own language pipeline unless `lang_code` is set.

## SSML (experimental)

Send `ssml: true` together with `allow_voice_tags: true`:

```json
{
  "model": "kokoro",
  "input": "<speak>Hi<break time=\"750ms\"/>there</speak>",
  "voice": "af_bella",
  "allow_voice_tags": true,
  "ssml": true
}
```

Mapping: `<break>` to a pause, `<voice name>` to a voice tag, `<prosody rate>` to a rate tag (`pitch` and `volume` ignored), `<phoneme alphabet="ipa">` to the IPA form, `<sub alias>` speaks the alias; other markup is dropped and its text spoken. Malformed SSML is a 400; DTDs are refused. `POST /dev/ssml` with `{"text": "<speak>..."}` shows the translated tags without synthesis.

## Captions

`POST /dev/captioned_speech` with the speech body plus `"stream": false` returns JSON with base64 `audio` and `timestamps` (word level); with `"stream": true` it returns JSON lines of the same shape. With `allow_voice_tags` each timestamp also carries its `voice`. For chunk-level timing on the normal route use `stream`, `return_download_link` and `return_timing`, then fetch the `X-Timing-Path` sidecar after the stream ends (earlier is a 404).

## Phonemes

```bash
curl -sS "$B/dev/phonemize" -H 'Content-Type: application/json' -d '{"text":"Hello world!","language":"a"}' | jq .
curl -sS "$B/dev/generate_from_phonemes" -H 'Content-Type: application/json' -H 'Accept: audio/wav' \
  -d '{"phonemes":"<from above>","voice":"af_bella"}' -o speech.wav
```

## Voice tuning (off by default)

`POST /dev/tune` takes a 3 to 30 second clip of one English speaker and speaks with a voice tuned toward it (via inno-kokoro). Upstream calls it a tuner, not a cloner. Enable with `ENABLE_INNO_TUNER=true`; saving needs `ALLOW_LOCAL_VOICE_SAVING=true`. Only tune voices you have permission to use. Details in the repo's `docs/inno-tune.md`.
