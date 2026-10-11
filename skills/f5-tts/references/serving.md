# F5-TTS: serving

> Verified against F5-TTS 1.1.22 (README, infer_gradio.py, socket_server.py, runtime/triton_trtllm), 2026-10-11

F5-TTS ships three ways to run it as a process. None is an OpenAI-compatible API and none authenticates.

## Gradio app

```bash
f5-tts_infer-gradio                          # Gradio default host and port (7860)
f5-tts_infer-gradio --host 127.0.0.1 --port 7860
f5-tts_infer-gradio --root_path /myapp        # when served under a sub-path
```

Features per the README: basic TTS with chunk inference, multi-style and multi-speaker generation, voice chat with Qwen2.5-3B-Instruct, and community language checkpoints. Flags in the source: `--port/-p`, `--host/-H`, `--share/-s` (public Gradio link), `--api/-a` (default true, allows API access), `--root_path/-r`, `--inbrowser/-i`. Never pass `--share` on a shared machine; in Docker the app needs `--host 0.0.0.0`, so publish the port on `127.0.0.1` only. The Gradio API is usable with the `gradio_client` package, but its endpoint names depend on the installed version (check `/?view=api`).

## Socket server (streaming)

```bash
python src/f5_tts/socket_server.py --host 127.0.0.1 --port 9998 \
  --ref_audio ref.wav --ref_text "Words in the reference clip."
python src/f5_tts/socket_client.py            # reference client; needs PyAudio
```

Defaults: `--host 0.0.0.0` (change it), `--port 9998`, `--model F5TTS_v1_Base`, ref audio the bundled English example. Protocol read from the source: the client sends UTF-8 text on a TCP socket; the server streams back float32 audio chunks as raw bytes (24 kHz in the F5TTS configs), ends each utterance with the literal bytes `END`, and also writes `output.wav` in its working directory. It serves one client connection at a time and has no authentication or TLS. Use it on loopback or a private network only.

## TensorRT-LLM and Triton

`src/f5_tts/runtime/triton_trtllm` holds a Triton plus TensorRT-LLM deployment. README benchmark (single L20, 16 NFE, 26 prompt and text pairs): Client-Server at concurrency 2 gave 253 ms average latency and RTF 0.0394; offline TRT-LLM 0.0402; offline PyTorch 0.1467. Follow that directory's README; this skill did not run it.

## Putting it behind an HTTP API

There is no official OpenAI-compatible wrapper. Options, none verified here:

- Write a small service that loads `F5TTS` once and exposes one POST route, with auth and request limits in front. Keep reference clips server side, selected by name, so callers cannot upload arbitrary audio.
- Community wrappers exist; check licence, maintenance and security before use.
- For an OpenAI-shaped TTS with fixed voices, use `kokoro-fastapi` instead.

## Memory and concurrency

One process holds the model and generates one utterance at a time; scale with processes and GPU memory. Auto-transcription of references loads a second model (`whisper-large-v3-turbo`), so pass `ref_text` explicitly in services. Measure memory with `nvidia-smi` rather than quoting figures; upstream publishes none for VRAM.
