# whisper.cpp: whisper-cli

> Verified against whisper.cpp v1.9.5 (examples/cli/cli.cpp usage text and defaults, README quick start), 2026-10-11

`whisper-cli` (the old `main` binary) transcribes files. Flags below are the usage block of `cli.cpp` at v1.9.5; run `whisper-cli -h` for the installed build.

## Basic use

```bash
./build/bin/whisper-cli -m models/ggml-large-v3-turbo.bin -f samples/jfk.wav -l auto
./build/bin/whisper-cli -m models/ggml-large-v3-turbo.bin -f talk.wav -l auto -otxt -osrt -of out/talk
```

- Input: the README says `whisper-cli` "currently runs only with 16-bit WAV files", and gives `ffmpeg -i input.mp3 -ar 16000 -ac 1 -c:a pcm_s16le output.wav` to convert. The examples decode with miniaudio by default; a build with `-DWHISPER_COMMON_FFMPEG=yes` decodes more formats (`install.md`). Trust the README for portability and convert to WAV.
- Default model path is `models/ggml-base.en.bin` (an English-only model), and the default language is `en`. Pass `-m` and `-l`.
- `-of FNAME` sets the output path **without extension**; each `-o*` flag adds the matching extension.

## Flags worth knowing

| Flag                                                                   | Meaning                                                                           |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `-m FNAME`, `-f FNAME`                                                 | model and input file                                                              |
| `-l LANG`, `-dl`                                                       | language (`auto` detects); `-dl` prints the detected language and exits           |
| `-tr`                                                                  | translate to English (needs a multilingual model)                                 |
| `-t N`, `-p N`                                                         | threads (default `min(4, hardware threads)`) and processors                       |
| `-ng`, `-dev N`                                                        | disable GPU; choose GPU device id                                                 |
| `-fa`, `-nfa`                                                          | enable or disable flash attention (on by default in the v1.9.5 source)            |
| `-otxt -ovtt -osrt -olrc -ocsv -oj -ojf`                               | write text, WebVTT, SubRip, LRC, CSV, JSON, or JSON with more information         |
| `-owts`, `-fp`                                                         | karaoke script output and font path                                               |
| `-nt`, `-np`, `-pc`, `-pp`, `-ps`                                      | no timestamps; print only results; colour by confidence; progress; special tokens |
| `--print-confidence`                                                   | print confidence                                                                  |
| `-ml N`, `-sow`                                                        | maximum segment length in characters; split on word instead of token              |
| `-bo N`, `-bs N`                                                       | best-of candidates and beam size                                                  |
| `-tp N`, `-tpi N`, `-nf`                                               | temperature, temperature increment, disable temperature fallback                  |
| `-et N`, `-lpt N`, `-nth N`                                            | entropy, log-probability and no-speech thresholds                                 |
| `--prompt TEXT`, `--carry-initial-prompt`                              | initial prompt (at most `n_text_ctx/2` tokens); always prepend it                 |
| `-ot MS`, `-d MS`                                                      | start offset and duration in milliseconds                                         |
| `-di`, `-tdrz`                                                         | stereo diarization; tinydiarize (needs a `-tdrz` model)                           |
| `-dtw MODEL`                                                           | token-level timestamps by dynamic time warping                                    |
| `-sns`, `--suppress-regex REGEX`                                       | suppress non-speech tokens; suppress tokens matching a regex                      |
| `--grammar GRAMMAR`, `--grammar-rule RULE`, `--grammar-penalty N`      | GBNF grammar to guide decoding                                                    |
| `--vad`, `-vm FNAME` and `-vt`, `-vspd`, `-vsd`, `-vmsd`, `-vp`, `-vo` | voice activity detection (below)                                                  |
| `--version`                                                            | print version info and exit                                                       |

## Voice activity detection

`--vad -vm <vad-model>` runs a VAD model first and sends only the detected speech segments to Whisper (README). Download the Silero model with:

```bash
./models/download-vad-model.sh silero-v6.2.0     # writes models/ggml-silero-v6.2.0.bin
./build/bin/whisper-cli -vm models/ggml-silero-v6.2.0.bin --vad -f samples/jfk.wav -m models/ggml-base.en.bin
```

Tuning (usage text defaults): threshold `-vt` 0.50, minimum speech `-vspd` 250 ms, minimum silence `-vsd` 100 ms, padding `-vp` 30 ms, overlap `-vo` 0.10 s, maximum speech duration `-vmsd` unlimited (set it to auto-split very long speech). The model files on Hugging Face (`ggml-org/whisper-vad`) were `ggml-silero-v5.1.2.bin` and `ggml-silero-v6.2.0.bin` on 2026-10-11.

## Benchmark and quantize

```bash
./build/bin/whisper-bench -m models/ggml-base.en.bin -t 4          # encoder timing; add -ng for CPU only
./build/bin/whisper-quantize models/ggml-base.en.bin models/ggml-base.en-q5_0.bin q5_0
```

The quantize types the tool accepts at v1.9.5: `q4_0 q4_1 q5_0 q5_1 q8_0 q2_k q3_k q4_k q5_k q6_k`. See `models.md` for quality trade-offs and the ready-made quantized downloads.

## Batch pattern

```bash
mkdir -p out
for f in audio/*.wav; do
  ./build/bin/whisper-cli -m models/ggml-large-v3-turbo.bin -f "$f" -l auto -np -nt -otxt -of "out/$(basename "${f%.wav}")"
done
```

Each invocation loads the model again. For many files, run `whisper-server` once and POST each file (`serve-configuration.md`, `scripts/transcribe.sh`).
