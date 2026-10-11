# llamafile security and sandbox

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

## Sandbox model

llamafile can sandbox itself with Cosmopolitan's `pledge()` and `unveil()`:

- **`pledge()`** is on by default. `--server` runs under `stdio anet rpath` on Linux: it can accept connections but not make outbound ones, cannot write, create, delete, exec or fork, and can read what the user can read. `--cli` and `--chat` run with no network at all.
- **`unveil()`** is opt-in with `--confine-reads` (server only): reads are limited to the executable and the directories holding the weights, mmproj, LoRA, draft model, `--media-path` and a `--path` web root. The model's whole parent directory becomes readable, so keep weights in a dedicated directory. Requests that read other paths fail.
- `--unsecure` turns the pledge sandbox off. Use it only to work around a `pledge failed` start error on an exotic kernel or outer seccomp policy.

Requirements: Linux 3.5+ for seccomp, 5.13+ for Landlock; on older kernels, macOS, Windows and other BSDs the sandbox is a no-op and llamafile logs that.

## Where it is not applied

- **GPU mode: no sandbox.** GPU drivers need device access that no promise set covers, so the sandbox is skipped whenever a GPU backend loads. This is the common production case. `--gpu disable` gives CPU inference with the sandbox.
- **Combined mode** (no mode flag): skipped, because it hosts an in-process HTTP client that connects out.
- **Outbound features** (`--rpc`, server-side tools, the MCP proxy) relax networking from `anet` to `inet`; writes and exec stay blocked.
- Model downloads (`-hf`, `--model-url`) happen before the sandbox is installed.
- Doc inconsistency: the 0.10 migration notes list "pledge() SECCOMP sandboxing" as missing, while the security page describes it as default. Verify on your build: `llamafile --server -m model.gguf --gpu disable & grep Seccomp /proc/$!/status` should show `Seccomp: 2`.

The sandbox is self-imposed: a modified llamafile from an untrusted source can omit it. Run untrusted llamafiles in a VM or container.

## Exposure checklist

1. Default bind is loopback. Add `--host 0.0.0.0` only when needed.
2. Set `--api-key-file` (not `--api-key`, which shows in `ps`) before any non-loopback bind. Keys are accepted as `Authorization: Bearer` or `X-Api-Key`.
3. Put TLS in front (`--ssl-key-file` and `--ssl-cert-file`, or `caddy`/`cloudflare-tunnel`/`tailscale` skills).
4. CORS and the Web UI origin restriction are not authentication.
5. Test which endpoints answer without a key (`curl` without the header against `/health`, `/props`, `/slots`, `/metrics`, `/tools`) and do not expose any that leak state; some llama.cpp endpoints may be public by design.
6. Do not run as root. For services use a dedicated user and a read-only weights directory.

## Built-in tools and agent mode

`--tools` lets a model run local actions (read and search files, write and edit files, shell commands). The HTTP `/tools` endpoint has no permission prompt; the Web UI prompt is not server-side authorization. When tools are enabled and `--cors-origins` is unset, allowed browser origins change from `*` to localhost. Enable only what you need (read-only subset first), never on a reachable server without an API key, and prefer containers for tool execution. `--agent` adds the experimental MCP proxy; avoid it unless needed.

## Supply chain

- Download only from `mozilla-ai` GitHub releases and the `mozilla-ai` Hugging Face organization; other llamafiles are arbitrary executables.
- No checksum file ships with the 0.10.6 release. Pin by version, record `sha256sum` of what you tested, and compare later downloads.
- Model files can carry licenses and parsers with their own bugs; the sandbox limits damage if the GGUF parser is exploited, but only when it is active.

## Whisper server

`whisper-server` accepts file uploads; run it unprivileged and sandboxed, loopback only unless fronted by authentication.
