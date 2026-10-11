# sparkDash: engine probes (vLLM, llama.cpp, SGLang, Ollama)

> Verified against sparkDash v2.32.0 (README "LLM server presets & backend auto-detection" and "LLM probe"), 2026-10-11

Each configured LLM port on a unit gets its own panel with independent backend detection, metrics and history. Add ports with **+ Add LLM port**; ports can change at runtime.

## How each engine is detected

| Engine                                | Signal                                                                            | Live tok/s                                       |
| ------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------ |
| llama.cpp                             | `/slots` per-slot timings; model from `/props`                                    | yes                                              |
| vLLM                                  | `/v1/models` plus Prometheus `/metrics` counters                                  | yes, from counter diffs                          |
| SGLang                                | `/server_info` (or `/get_server_info`) and `/model_info`                          | yes (`last_gen_throughput` when metrics are off) |
| Ollama                                | native `/api/tags`                                                                | no counters, tiles stay 0                        |
| LM Studio                             | `/api/v0/models` (load state)                                                     | no counters                                      |
| EXL3, TensorFold, FreeToken, ds4, q27 | `owned_by` on `/v1/models`, `/health`, `/v1/stats` or their own Prometheus series | engine-specific                                  |

Presets fill a port number only: LM Studio 1234, Ollama 11434, TensorFold 8888. Detection is positive-signature first so a server that answers 200 on every path is not mislabeled.

## Ports in this stack

- The default `LLM_PORT` 8888 matches nothing here; add real ports: vLLM 8000, SGLang 30000, Ollama 11434, llama-server (check your build; see `self-hosted-llms`), llama-swap 8080.
- Probes call engine endpoints directly. The README documents no API-key setting for probes, so a port that needs a bearer key (a gateway on 4000, or an engine started with `--api-key`) shows auth failures. Probe an unauthenticated loopback engine port instead. Whether the current UI has a key field is unverified; check Settings.
- vLLM needs its `/metrics` reachable; SGLang gives richer data with `--enable-metrics`; llama.cpp needs `/slots` enabled (default on; `--no-slots` hides it).
- A unit reached only over SSH (NAT forwards only SSH) is probed through an SSH forward after two failed direct probes; the panel shows a **via SSH** chip.
- Pin a multi-interface host's model API with the unit's **LLM host** field.

## Measuring speed

sparkDash never sends its own requests to measure speed. Decode, prefill and quality benches and the Prompt Showcase send real requests on demand and can load a model; run them only with approval. Remote benchmark targets must be in `SPARKDASH_BENCH_HOSTS`.

## Read-only checks

```bash
curl -fsS http://127.0.0.1:8000/v1/models | jq -r '.data[].id'        # vLLM or any OpenAI-compatible
curl -fsS http://127.0.0.1:8000/metrics | grep -c '^vllm:'
curl -fsS http://127.0.0.1:11434/api/tags | jq -r '.models[].name'    # Ollama
curl -fsS http://127.0.0.1:5555/api/sparks | jq '.[]|{id,name}'
```

## Official links

- README: https://github.com/MiaAI-Lab/sparkDash#llm-server-presets--backend-auto-detection
