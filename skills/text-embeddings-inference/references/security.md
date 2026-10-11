# TEI security

> Verified against text-embeddings-inference v1.9.4 (docs cli_arguments, README), 2026-10-11

- **Bind narrowly.** Publish `127.0.0.1:8080:80`, or a private interface or Tailscale address. TEI's default hostname is `0.0.0.0`, and the container port 80 is open to anything on the Docker network.
- **API key.** `--api-key` or `API_KEY` makes TEI require a token. Generate with `openssl rand -hex 24` into a `0600` env file. Let LiteLLM hold it (`api_key: os.environ/TEI_API_KEY`), so clients only carry LiteLLM virtual keys.
- **No TLS in TEI.** Terminate TLS in a reverse proxy (`caddy` skill) or keep traffic on loopback or a tunnel.
- **Gated models.** `HF_TOKEN` is needed at first download. Use a read-only token, store it in the env file, then remove it once weights are cached, or mount weights offline.
- **Supply chain.** Pull from `ghcr.io/huggingface/text-embeddings-inference`; pin a minor tag or a digest (`docker image inspect --format '{{index .RepoDigests 0}}'`). Models with custom code are a risk: TEI loads supported architectures natively, but still review the model repo.
- **CORS.** Leave `--cors-allow-origin` unset unless a browser calls TEI directly.
- **Metrics port 9000** exposes request stats; keep it internal.
- **Logs.** Do not run with debug logging on in shared environments, since request text can appear.
