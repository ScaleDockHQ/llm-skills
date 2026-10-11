# Chatterbox: serving

> Verified against resemble-ai/chatterbox master (gradio_*.py, multilingual_app.py, README), 2026-10-11

Upstream ships no HTTP API server and no container. What exists:

| Entry point               | What it does              | Exposure to watch                               |
| ------------------------- | ------------------------- | ----------------------------------------------- |
| `gradio_tts_app.py`       | original model UI         | `.launch(share=True)`: public Gradio link       |
| `gradio_tts_turbo_app.py` | Turbo UI with tag buttons | `.launch(share=True)`: public Gradio link       |
| `multilingual_app.py`     | multilingual UI           | `demo.launch(mcp_server=True)`: also serves MCP |
| `gradio_vc_app.py`        | voice conversion UI       | check the file before running                   |

`share=True` opens a public tunnel to your machine for the session; the MCP flag exposes the generate tool to any MCP client that can reach the port. Before running a demo on a host that is not a private laptop, copy the file and edit `launch(...)` to `server_name="127.0.0.1"` without `share`, or front it with an authenticating reverse proxy (see the `caddy` skill).

## Writing a service

Keep it small, loopback-only, authenticated:

1. Load the model once at startup, on the target device.
2. One generation at a time per model instance (use a lock or a single worker); concurrent calls on one instance contend for the GPU and share the conditioning state, which `audio_prompt_path` overwrites (`prepare_conditionals` sets `self.conds`). For multiple voices serialise by voice or keep one instance per voice.
3. Cache conditionals per voice instead of passing the clip each request.
4. Return WAV bytes with the sample rate from `model.sr`.
5. Bind `127.0.0.1`, require a bearer token from an environment variable, and limit text length.

For an OpenAI-compatible `/v1/audio/speech` endpoint without writing code, use `speaches` or `kokoro-fastapi` (fixed voices). Third-party Chatterbox API wrappers exist; none was reviewed for this skill, so audit before use.

## Placement

Chatterbox shares a GPU with LLMs poorly if unmanaged. Use `llama-swap` or run it on a separate device, and see `self-hosted-genmedia` for placement. Install commands are in the skill's Companion section.
