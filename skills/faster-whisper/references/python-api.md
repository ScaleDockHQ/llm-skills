# faster-whisper: Python API

> Verified against faster-whisper v1.2.1 (README, faster_whisper/transcribe.py, vad.py), 2026-10-11

## Load a model

```python
from faster_whisper import WhisperModel

model = WhisperModel("large-v3", device="cuda", compute_type="float16")
# int8 on GPU: compute_type="int8_float16"; CPU: device="cpu", compute_type="int8"
```

Constructor arguments (source defaults):

| Argument                     | Default     | Meaning                                                                                          |
| ---------------------------- | ----------- | ------------------------------------------------------------------------------------------------ |
| `model_size_or_path`         | required    | size name, local converted directory, or a CTranslate2 Whisper model id on the Hub               |
| `device`                     | `"auto"`    | `"cpu"`, `"cuda"` or `"auto"`                                                                    |
| `device_index`               | `0`         | GPU id, or a list such as `[0, 1]` to use several GPUs from several Python threads               |
| `compute_type`               | `"default"` | see `performance-memory.md`; `default` keeps the stored quantization where supported             |
| `cpu_threads`                | `0`         | docstring says 4 by default; a non-zero value overrides `OMP_NUM_THREADS`                        |
| `num_workers`                | `1`         | parallel `generate()` calls when `transcribe()` runs from several threads, at the cost of memory |
| `download_root`              | `None`      | model cache directory; default is the Hugging Face cache                                         |
| `local_files_only`           | `False`     | never download; use the cached copy                                                              |
| `revision`, `use_auth_token` | `None`      | Hub revision and token for private models                                                        |

## Transcribe

```python
segments, info = model.transcribe("audio.mp3", beam_size=5, language="en")
print(info.language, info.language_probability, info.duration, info.duration_after_vad)
for s in segments:                       # the work happens here
    print(f"[{s.start:.2f}s -> {s.end:.2f}s] {s.text}")
```

`segments` is a **generator**: `segments = list(segments)` forces completion. `Segment` fields: `id, seek, start, end, text, tokens, avg_logprob, compression_ratio, no_speech_prob, words, temperature`. `Word` fields: `start, end, word, probability`.

Key `transcribe()` options and defaults in v1.2.1:

| Option                                      | Default                | Notes                                                                 |
| ------------------------------------------- | ---------------------- | --------------------------------------------------------------------- |
| `language`                                  | `None` (auto-detect)   | ISO code; set it when known                                           |
| `task`                                      | `"transcribe"`         | `"translate"` translates to English                                   |
| `beam_size`, `best_of`, `patience`          | `5`, `5`, `1`          | openai-whisper uses beam 1                                            |
| `temperature`                               | fallback list from 0.0 | retried on high compression ratio or low log-prob                     |
| `compression_ratio_threshold`               | `2.4`                  | triggers temperature fallback                                         |
| `log_prob_threshold`, `no_speech_threshold` | `-1.0`, `0.6`          | silence and low-confidence handling                                   |
| `condition_on_previous_text`                | `True`                 | set `False` for distil-large-v3 (README) and to stop repetition loops |
| `initial_prompt`, `hotwords`                | `None`                 | bias vocabulary and names                                             |
| `word_timestamps`                           | `False`                | adds `segment.words`                                                  |
| `vad_filter`                                | `False`                | `True` removes long silences with Silero VAD                          |
| `vad_parameters`                            | `None`                 | dict or `VadOptions`                                                  |
| `without_timestamps`                        | `False`                | `True` is faster, no per-segment timing granularity                   |
| `multilingual`                              | `False`                | per-segment language switching for mixed-language audio               |
| `clip_timestamps`                           | `"0"`                  | transcribe only given ranges                                          |
| `hallucination_silence_threshold`           | `None`                 | with word timestamps, skips silent stretches that produce text        |

## VAD

```python
segments, _ = model.transcribe("audio.mp3", vad_filter=True,
                               vad_parameters=dict(min_silence_duration_ms=500))
```

`VadOptions` defaults: `threshold=0.5`, `min_speech_duration_ms=0`, `max_speech_duration_s=inf`, `min_silence_duration_ms=2000`, plus `speech_pad_ms`, `neg_threshold`. The default is conservative: it removes only silence longer than 2 seconds. Speaches uses `min_silence_duration_ms=160, max_speech_duration_s=30` instead.

## Batched transcription

```python
from faster_whisper import WhisperModel, BatchedInferencePipeline
model = WhisperModel("turbo", device="cuda", compute_type="float16")
batched = BatchedInferencePipeline(model=model)
segments, info = batched.transcribe("audio.mp3", batch_size=16)
```

`BatchedInferencePipeline.transcribe` is a drop-in for `WhisperModel.transcribe`. In the batched path `vad_filter` defaults to `True`, `batch_size` defaults to 8, and `without_timestamps` defaults to `True`. Batching trades VRAM for speed (`performance-memory.md`).

## Word timestamps

```python
segments, _ = model.transcribe("audio.mp3", word_timestamps=True)
for s in segments:
    for w in s.words:
        print(f"[{w.start:.2f}s -> {w.end:.2f}s] {w.word}")
```

Speaker labels are not in faster-whisper; see WhisperX and others in `integrations.md`.

## Logging

```python
import logging
logging.basicConfig()
logging.getLogger("faster_whisper").setLevel(logging.DEBUG)
```
