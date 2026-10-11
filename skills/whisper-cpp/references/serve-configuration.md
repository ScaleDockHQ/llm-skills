# whisper.cpp: whisper-server configuration

> Verified against whisper.cpp v1.9.5 (examples/server/server.cpp and README.md at the tag), 2026-10-11

`whisper-server` is a small cpp-httplib server around one loaded model. It is an example program, not a hardened service: no auth, no TLS, one request at a time.

## A safe command

```bash
./build/bin/whisper-server \
  --host 127.0.0.1 --port 8080 \
  -m models/ggml-large-v3-turbo.bin \
  -l auto \
  --convert --tmp-dir /var/tmp/whisper \
  --vad -vm models/ggml-silero-v6.2.0.bin
```

- `--host` defaults to `127.0.0.1` and `--port` to `8080`. Keep loopback; inside a container use `0.0.0.0` and publish `127.0.0.1:` on the host.
- `-m` defaults to `models/ggml-base.en.bin`, an English-only model. `-l` defaults to `en`: **transcribing other languages without `-l auto` or the code returns wrong text.** Per-request `language` overrides it (`api.md`).
- `--convert` pipes each upload through `ffmpeg -i in -y -ar 16000 -ac 1 -c:a pcm_s16le out.wav` (two channels with diarization). It requires `ffmpeg` on the host; the server runs `ffmpeg -version` at start and **exits with status 0** after printing "ffmpeg is not found" if it is missing. Without it, upload WAV. Temporary files go to `--tmp-dir` (default `.`, the working directory).
- `-fa`/`-nfa`: flash attention, **on by default in the v1.9.5 source** (the README help block still shows `[false]`). `-ng` disables the GPU, `-dev N` or `WHISPER_ARG_DEVICE=N` picks a GPU.
- `-t N` threads, default `min(4, hardware threads)`; `-p N` processors, default 1.
- `--public PATH` is the folder for static files (default `examples/server/public`); `GET <request-path>/` serves a small upload form.

## Request path mapping

`--request-path PATH` prefixes every route and `--inference-path PATH` names the transcription route (default `/inference`). Routes registered at v1.9.5 (`server.cpp`):

| Route                            | Method | Purpose                                                                          |
| -------------------------------- | ------ | -------------------------------------------------------------------------------- |
| `<request-path>/`                | GET    | upload form                                                                      |
| `<request-path><inference-path>` | POST   | transcribe (and `OPTIONS` for CORS preflight)                                    |
| `<request-path>/load`            | POST   | form field `model` = a server-side path; replaces the loaded model               |
| `<request-path>/health`          | GET    | `200 {"status":"ok"}` when ready, `503 {"status":"loading model"}` while loading |

So `--request-path /v1/audio --inference-path /transcriptions` serves `POST /v1/audio/transcriptions` and `GET /v1/audio/health`. This mapping is not described in the README; it comes from reading `server.cpp`. Without the flags the routes are `/inference`, `/load`, `/health`.

## Defaults that matter (server `whisper_params`)

| Setting                | Default at v1.9.5               | Flag                           |
| ---------------------- | ------------------------------- | ------------------------------ |
| language               | `en`                            | `-l`                           |
| response format        | `json`                          | per-request `response_format`  |
| timestamps             | on                              | `-nt` off                      |
| flash attention        | on                              | `-nfa` off                     |
| no_context             | true (each request independent) | no flag                        |
| best-of / beam size    | 2 / -1 (greedy)                 | `-bo`, `-bs`                   |
| temperature fallback   | on                              | `-nf` off                      |
| no-speech threshold    | 0.60                            | `-nth`                         |
| VAD                    | off                             | `--vad -vm <model>`            |
| read and write timeout | 600 s each, **no flag**         | compile-time (`server_params`) |

Server-level flags set the defaults; a request can override most decoding fields with multipart form fields (`api.md`). A file that runs longer than the 600 s read or write window fails with the connection closed; split very long audio.

## Concurrency

`POST` handlers take a global mutex, so requests run **one at a time** per process and the rest queue in the HTTP layer. Run several processes (one per GPU, different ports) behind a proxy for parallelism. A `POST /load` also takes the mutex and swaps the model in place: it frees the old context first, and on a failed load the process **exits** (`model init failed, no model loaded must exit`). Prefer separate processes per model in a llama-swap setup.

## Security

Upstream's README warns, verbatim in intent: do not run the server with administrative privileges, run it in a sandbox, and validate inputs, because it accepts file uploads and uses ffmpeg for format conversion. In practice:

- unprivileged user, loopback bind, no secrets in its environment;
- a systemd unit with `NoNewPrivileges=true`, `PrivateTmp=true`, `ProtectSystem=strict` and a `ReadWritePaths` for `--tmp-dir` (see `templates/whisper-server.service`);
- put auth and rate limits in the reverse proxy, llama-swap `apiKeys`, or LiteLLM; the server has none;
- the bundled web page and `/load` (which reads any path the process can read) are reasons not to expose it.

## Run as a service

```bash
mkdir -p ~/.config/systemd/user && cp templates/whisper-server.service ~/.config/systemd/user/
# edit paths, then:
systemctl --user daemon-reload && systemctl --user enable --now whisper-server
journalctl --user -u whisper-server -f
```

The process handles SIGINT and SIGTERM with a graceful stop (source). Under llama-swap, let llama-swap manage the process instead (`combos/llama-swap-litellm.md`).

## Verify

```bash
curl -fsS http://127.0.0.1:8080/health                          # {"status":"ok"}
scripts/transcribe.sh samples/jfk.wav                           # prints the text
ss -ltnp 2>/dev/null | grep whisper-server                      # 127.0.0.1 only
```
