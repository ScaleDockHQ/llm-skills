# KoboldCpp features

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

## Chat templates, tools and reasoning

- Default adapter `AutoGuess` picks instruct tags from the model. Override with `--chatcompletionsadapter file.json`.
- `--jinja` formats `/v1/chat/completions` with the model's Jinja template (other endpoints unaffected).
  Tool calls are not templated through jinja unless `--jinja_tools` is also set. `--jinjatemplate file`
  replaces the model's template; `--jinja_kwargs '{"enable_thinking":false}'` passes template variables.
- Incoherent output usually means the wrong template: relaunch with `--jinja` (README troubleshooting).
- Tools: send OpenAI `tools` and `tool_choice`; KoboldCpp reads `tool_choice` (default `auto`, an object means
  `required`). Test with a real call, results depend on the model.
- Reasoning: `--jinjathink default|true|false` toggles thinking in the template; `--reasoningeffort` sets a
  default effort (API values override). Streamed reasoning arrives as `reasoning_content` deltas.
- Defaults for sampling: `--gendefaults '{"temperature":0.6}'` fills fields clients omit;
  `--gendefaultsoverwrite` forces them.

## MCP, web search, agent

- `--mcpfile mcp.json`: Claude Desktop style MCP server config. KoboldCpp also exposes an MCP proxy at
  `POST /mcp` (password protected). MCP servers run commands from that file: only use files you trust.
- `--websearch`: local search engine proxy so web searches work from the UI.
- `--agent`: the bundled KoboldCpp Agent (writes code, runs programs, schedules tasks). It raises
  `--contextsize` to at least 28672, `--defaultgenamt` to 8192 and enables jinja and jinja tools. It can
  execute programs: treat as a privileged tool, loopback only (with `--cli` it forces `--host 127.0.0.1`).

## Vision and audio input

`--mmproj` enables image input; capability shows in `/api/extra/version` (`vision`, `audio`). Some
multimodal models also take audio (README lists Gemma4 E2B and E4B). Limit cost with `--visionmaxres`.

## Image and video generation

`--sdmodel` loads a safetensors or GGUF image model (README lists SD1.5, SDXL, SD3, Flux, Qwen Image and
more, and WAN 2.2 and LTX video). Related: `--sdvae`, `--sdclip1/2`, `--sdllm`, `--sdlora`, `--sdquant 0|1|2`,
`--sdoffloadcpu`, `--sdvramlimit MB`, `--sdclamped` (limit size for shared use), `--sdflashattention`,
`--sdtiledvae`. Endpoints: A1111 `/sdapi/v1/txt2img`, `/img2img`, `/upscale`; OpenAI
`/v1/images/generations` and `/v1/images/edits`; ComfyUI-style `/prompt` emulation; UI at `/sdui`.
Image endpoints are not covered by `--password`.

## Speech and music

- STT: `--whispermodel`; `/v1/audio/transcriptions`, `/api/extra/transcribe`.
- TTS: `--ttsmodel` (+ `--ttswavtokenizer`, `--ttsgpu`, `--ttsdir` for cloning voices); `/v1/audio/speech`,
  `/api/extra/tts`, XTTS-style `/tts_to_audio`; voices at `/v1/audio/voices`.
- Music: `--musicllm`, `--musicdiffusion`, `--musicembeddings`, `--musicvae`, `--musiclowvram`;
  `/api/extra/music/generate`, UI at `/musicui`.

## Embeddings

`--embeddingsmodel` (+ `--embeddingsmaxctx`, `--embeddingsgpu`); `/v1/embeddings`, `/api/extra/embeddings`, Ollama
`/api/embed`.

## Writing and roleplay

Bundled KoboldAI Lite UI: memory, world info, author's note, characters (Tavern cards), scenarios, saves.
Server-side persistence: `--savedatafile`; shared sessions: `--multiplayer`; hosted story: `--preloadstory`.
Classifier-free guidance (negative prompts): `--enableguidance`, costs memory and speed. Grammar:
`/api/extra/json_to_grammar` converts JSON schema to GBNF.

## Speculative decoding and LoRA

See `performance-tuning.md` and `models-and-formats.md`.

## Check what is active

```bash
curl -s http://127.0.0.1:5001/api/extra/version | jq .   # llm, txt2img, vision, audio, whisper, tts, embeddings, music, mcp, jinja, router, admin flags
```
