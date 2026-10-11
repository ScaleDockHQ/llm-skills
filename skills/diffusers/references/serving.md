# Diffusers: serving over HTTP

> Verified against Diffusers v0.41.0 (docs using-diffusers/create_a_server, examples/server/server.py, examples/server-async/README.md), 2026-10-11

Diffusers is a library; it has no supported production server. The repo ships two examples, and the docs call the first a way to use pipelines as an inference engine.

## examples/server

```bash
git clone https://github.com/huggingface/diffusers && cd diffusers/examples/server
pip install -r requirements.txt && pip install ../..       # docs: pip install . then pip install -f requirements.txt
MODEL_PATH=stabilityai/stable-diffusion-3.5-medium python server.py
curl -X POST -H "Content-Type: application/json" \
  --data '{"model": "something", "prompt": "a kitten in front of a fireplace"}' http://localhost:8000/v1/images/generations
```

Facts from the source at the time of writing:

- FastAPI app, `uvicorn.run(app, host="0.0.0.0", port=8000)`. **It binds every interface with no authentication.** Put it behind a firewall rule, SSH tunnel or a gateway with keys, or edit the host to `127.0.0.1`.
- `MODEL_PATH` defaults to `stabilityai/stable-diffusion-3.5-large` (or `-medium` in the fallback branch); the code is SD3-specific (`StableDiffusion3Pipeline`).
- `POST /v1/images/generations` returns `{"data": [{"url": ...}]}` — a URL to a saved file served by the app, **not** `b64_json`. OpenAI clients expecting base64 need a shim.
- Request handling: each request builds a pipeline view from the shared pipeline with a fresh scheduler (`from_pipe`), a per-request `torch.Generator` seeded randomly, and runs inference in a thread (`run_in_executor`). The scheduler is not thread-safe; sharing one across threads raises `IndexError: index 21 is out of bounds for dimension 0 with size 21`.
- The generator device is hard-coded to `"cuda"` (docs comment: or mps, xpu, cpu); edit it on other hardware.

## examples/server-async

A demo that keeps one model in memory and serves parallel requests through request-scoped pipeline views, cloned schedulers and tokenizer locks (`RequestScopedPipeline`). Upstream recommends 10 to 50 parallel inferences only on GPUs with 35 GB VRAM or more, and one or two otherwise to avoid decoding or saving errors from memory shortages. Treat both as demos.

## Putting a real front on it

- For one model per process behind llama-swap and LiteLLM with OpenAI-shaped images, `stable-diffusion-cpp` already speaks `/v1/images/generations`; with Diffusers write a small wrapper that returns `b64_json`, and serialize GPU access (one generation at a time per GPU) unless you have measured headroom.
- Add authentication, request size and step limits, and timeouts at the gateway (`litellm`, `llm-gateway`).
- Cold start loads multi-GB weights; keep the process warm or let llama-swap own the lifecycle (`llama-swap`).
- Bind to `127.0.0.1` by default and publish deliberately.
