# Hub CLI, tokens, download, upload and cache

> Verified against huggingface_hub CLI guide (hf auth, download, upload, repos, cache), Hub security tokens page, huggingface.co/docs/hub, 2026-10-11

## Install

```bash
pip install -U huggingface_hub        # or: uv tool install huggingface_hub
hf version
```

`hf` replaces the old `huggingface-cli`. Output formats: `--format auto|human|agent|json|quiet`, plus `--json` and `-q`. Under an AI agent the CLI auto-selects the `agent` format and never prompts.

## Tokens

- Roles: `fine-grained` (specific resources; recommended for production), `read`, `write`. Create at Settings, Access Tokens.
- One token per app or machine so each can be invalidated alone. Inference Providers needs the fine-grained permission "Make calls to Inference Providers".
- CI: Trusted Publishers exchanges an OIDC identity for a short-lived token, avoiding stored secrets.
- Leaked token: delete or refresh it in Access Tokens. Anyone can invalidate a leaked token they found with `POST /api/credentials/revoke` (always returns 202).
- Do not pass tokens on command lines: they land in shell history. Use `HF_TOKEN` or `hf auth login` interactively.

```bash
umask 077
mkdir -p ~/.config && read -rs -p "HF token: " K && printf '%s' "$K" > ~/.config/hf.token && unset K
export HF_TOKEN="$(cat ~/.config/hf.token)"
hf auth whoami          # prints username and orgs, not the token
```

`hf auth logout` does not log you out when `HF_TOKEN` is set; unset the variable. Scripted login exists (`hf auth login --token ...`), but prefer the environment variable.

## Download

```bash
hf download <repo>                                # whole repo into the cache
hf download <repo> config.json model.safetensors  # chosen files
hf download <repo> --include "*.safetensors" --exclude "*.fp16.*"
hf download <repo> --revision <sha-or-branch>     # pin
hf download <repo> --repo-type dataset            # or space
hf download <repo> --local-dir ./weights          # copy to a folder instead of the cache layout
hf download <repo> --dry-run                      # see what would download and the size
hf download hf://datasets/org/name@v1.1           # URI form
```

Without `--local-dir`, files go to the cache under `HF_HOME` (override with `--cache-dir`). Gated repos need accepted terms on the web page and a token with access. Use `-q` to silence progress in scripts. Check disk space before large pulls (`df -h`).

## Upload

```bash
hf upload <repo> . .                       # whole folder to repo root, creates the repo if missing
hf upload <repo> ./out /models             # folder to a path in the repo
hf upload <repo> ./a.safetensors a.safetensors
hf upload <repo> ./out . --include "*.safetensors" --delete "*.tmp"
```

Create explicitly with visibility: `hf repos create org/name [--repo-type dataset|space] [--private]`. Default to private for anything not meant to be public. Prefer `hf upload` over git for large files.

## Repos and models

`hf models ls --search ... [--warm]` (`--warm` means served by at least one inference provider), `hf models info <repo>`, `hf models card <repo>`, `hf repos create|delete|duplicate`, `hf buckets ...` for object storage. Run `hf --help` for the current command list.

## Cache

```bash
hf cache ls                       # repos and sizes
hf cache rm model/org/name --dry-run
hf cache rm model/org/name        # prompts; add --yes in scripts
hf cache rm hf://models/org/repo/file.gguf --dry-run   # a single file
hf cache prune                    # detached revisions
```

`hf cache rm` takes repo IDs, `hf://` URIs or revision hashes. Single-file removal is exact-path only (no globs). Use `--cache-dir PATH` for non-default caches.

## Official links

- CLI guide: https://huggingface.co/docs/huggingface_hub/guides/cli
- Tokens: https://huggingface.co/docs/hub/security-tokens
