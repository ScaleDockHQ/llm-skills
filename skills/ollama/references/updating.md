# Ollama: updating

> Verified against Ollama v0.40.3, 2026-10-11

Docs: faq, linux, windows, macos, docker, troubleshooting; GitHub releases; Docker Hub tags

Ollama ships frequently (v0.40.0 on 2026-09-25 through v0.40.3 on 2026-10-11 at writing), and new model support often needs the new version. Read the release notes (https://github.com/ollama/ollama/releases) before jumping several versions, and snapshot what runs.

## Before

```bash
ollama -v; ollama ls > /tmp/ollama-models-before.txt; ollama ps
```

Models in the store are kept across updates. Note the pinned version so you can roll back.

## Per platform

- **macOS app / Windows app:** they download updates automatically; click the menu bar or tray item, "Restart to update". Manual: download the latest from https://ollama.com/download. Windows keeps update logs in `%LOCALAPPDATA%\Ollama\upgrade.log`; when installing the standalone zip, remove old directories first.
- **macOS script / Linux script:** re-run `curl -fsSL https://ollama.com/install.sh | sh`. It replaces the app on macOS and cleans the old `lib/ollama` on Linux. Pin with `OLLAMA_VERSION=0.40.3`.
- **Linux manual:** `sudo rm -rf /usr/lib/ollama`, then extract the new `ollama-linux-<arch>.tar.zst` (plus the `-rocm` archive on AMD) into `/usr`, then `sudo systemctl restart ollama`.
- **Windows script:** `irm https://ollama.com/install.ps1 | iex` (`$env:OLLAMA_VERSION` to pin).
- **Homebrew:** `brew upgrade ollama` then restart the service (`brew services restart ollama`).
- **Docker:** change the tag, pull and recreate. The store volume carries over.

```bash
docker pull ollama/ollama:0.40.3 && docker stop ollama && docker rm ollama
docker run -d --gpus=all -v ollama:/root/.ollama -p 127.0.0.1:11434:11434 --name ollama ollama/ollama:0.40.3
```

Prefer a pinned tag over `latest` on servers; ROCm images use the `-rocm` suffix.

## After

```bash
curl -s http://127.0.0.1:11434/api/version | jq .
ollama ls | diff - /tmp/ollama-models-before.txt && echo "models unchanged"
for m in $(ollama ls | awk 'NR>1{print $1}'); do echo "== $m"; curl -s http://127.0.0.1:11434/api/generate -d "{\"model\":\"$m\",\"prompt\":\"hi\",\"stream\":false,\"options\":{\"num_predict\":8}}" | jq -r '.response // .error'; done
```

(The loop loads every model one after another; skip it on a box with large models and test only what matters. Embedding models need `/api/embed` instead.)

If GPU use regressed after an update: `ollama ps`, then `troubleshooting.md` (drivers, ROCm 7 requirement, `nvidia_uvm` reload).

## Roll back

Reinstall the previous version: `OLLAMA_VERSION=<old> sh` (Linux/macOS script), the old Docker tag, or the matching release archive. A model pulled or created with a newer Ollama may declare `REQUIRES <version>` in its Modelfile and refuse to run on older ones.

## Pre-releases

Release candidates exist as `-rc` Docker tags and GitHub pre-releases; `OLLAMA_VERSION` accepts them. Do not run them on shared servers.

## Models

Models update only when you pull again: `ollama pull <model>` re-checks the tag and downloads changed layers. Library tags can be replaced by their publishers, so for reproducibility note the digest from `ollama ls`/`ollama show`, or create your own tag with `ollama cp`.
