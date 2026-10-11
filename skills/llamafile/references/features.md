# llamafile features

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

Server features come from the llama.cpp build bundled in the file, so what works depends on the release; confirm with `llamafile --server --help`.

## Tool calling

The OpenAI, Responses and Anthropic APIs let a model request function calls but never run them: the client runs the loop (send tools, read `tool_calls`, execute, return results). Serve agents with `--jinja` and a large `--ctx-size`. `--tools` is not needed for client-defined functions.

Shapes by API are in `references/api.md`.

## Built-in tools (experimental)

Server mode only, off by default, enabled with `--tools`:

```bash
llamafile -m model.gguf --server --tools read_file,file_glob_search,grep_search,get_datetime   # read-only subset
llamafile -m model.gguf --server --tools all                                                  # includes writing and shell
```

Tools: `read_file`, `file_glob_search`, `grep_search`, `get_datetime`, `get_info` (read), `write_file`, `edit_file` (write), `exec_shell_command` (execute). List the exact set with `curl http://127.0.0.1:8080/tools`. The Web UI asks before running a tool; the HTTP `/tools` endpoint does not, and any client that reaches it (and passes the API key) can invoke an enabled tool. Tools run with the permissions of the llamafile process. `--agent` enables all tools plus an experimental MCP proxy; prefer `--tools`. See `references/security-and-sandbox.md`.

## Agentfile

`agentfile` is an in-tree, single-command agent (one model, a prompt in, an answer out, tools off by default). It exists on `main` but is not among the 0.10.6 release files, so build it from source or check later releases. Flags documented upstream: `--tools read_only|all|<list>`, `--yes` and `--confirm`, `--searxng-url`, and `--tools-runtime docker:IMAGE`, `docker-container:NAME` or `ssh:TARGET` to isolate tool execution. Use a container runtime for real isolation.

## Multimodal

`--mmproj` plus `--image` (CLI and chat), `/upload` in chat, and image or audio inputs through the API for models with a projector. Audio input needs a model with audio support; check `/v1/models` capabilities.

## Embeddings, rerank, structured output

- `--embedding` (with `--pooling`) enables `/v1/embeddings` and native `/embedding`; `--rerank` enables `/v1/rerank` and `/rerank`.
- `--grammar`, `--grammar-file`, `--json-schema`, `--json-schema-file` constrain output.
- `--reasoning-format`, `--reasoning-budget`, `--chat-template-kwargs` control reasoning models.

## Speculative decoding

`--draft`, `--draft-max`, `--draft-min`, `--draft-p-min`, `-cd` (draft context), `-ngld` (draft GPU layers) and the `-hfd` draft download flags exist in the bundled server. Benchmark before adopting.

## Web UI

`http://127.0.0.1:8080/` serves llama.cpp's Web UI. Some of its messages mention `llama-server`; substitute your llamafile name. Disable with `--no-webui`.

## Whisperfile and other programs

- `whisperfile` (whisper.cpp): `whisperfile -m models/ggml-tiny.en-q5_1.bin -f audio.wav --no-prints`. WAV 16 kHz 16-bit is preferred; MP3, FLAC and Ogg are converted. `--gpu auto|apple|amd|nvidia|disable`, `--no-gpu`.
- `whisper-server` (built from source): `--host` default 127.0.0.1, `--port` default 8080, `GET /health` (503 while loading), `POST /inference` with multipart `file`. It accepts uploads: do not run it privileged or exposed.
- In 0.10.* whisperfile has no Windows GPU support. Models come from `ggerganov/whisper.cpp` on Hugging Face.
- `transcribefile` (transcribe.cpp) and `diffusionfile` (Stable Diffusion) are separate release files; the 0.10 notes list Stable Diffusion as not yet ported while a `diffusionfile` is released, so test it before relying on it.

See `whisper-cpp` for whisper tuning (`npx skills add ScaleDockHQ/llms-skills --skill whisper-cpp`).
