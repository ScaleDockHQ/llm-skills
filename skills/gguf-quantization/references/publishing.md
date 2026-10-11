# GGUF quantization: split, name, document and publish

> Verified against llama.cpp v0.6.0 and master b11556, 2026-10-11

Publishing uploads someone's weights under your account: confirm the source license allows redistribution of derivatives, and get explicit approval before any upload.

## Naming

One file per quant, `<model>-<TYPE>.gguf` (for example `Qwen-X-Q4_K_M.gguf`); `mmproj-<model>-<type>.gguf` for the projector; keep the imatrix as `<model>.imatrix.gguf` so others can requantize. Hub tooling and llama.cpp's `-hf repo:TYPE` selector rely on the type appearing in the file name (check `llama-server --help` for `-hf` semantics on your build).

## Splitting

```bash
./build/bin/llama-gguf-split --split --split-max-size 20G m-Q4_K_M.gguf m-Q4_K_M       # writes m-Q4_K_M-00001-of-0000N.gguf ...
./build/bin/llama-gguf-split --merge m-Q4_K_M-00001-of-00003.gguf m-Q4_K_M.gguf
```

Options from upstream: `--split` (default), `--split-max-size` (`M` or `G`), `--split-max-tensors` (default 128), `--merge` (give the first shard and the output). llama.cpp loads a split model from its first shard. `llama-quantize --keep-split` keeps the input's sharding. `convert_hf_to_gguf.py --split-max-size` splits at convert time. Check the Hub documentation for current per-file size limits before choosing a shard size.

## Inspect and edit metadata

```bash
python ~/src/llama.cpp/gguf-py/gguf/scripts/gguf_dump.py --help
ls ~/src/llama.cpp/gguf-py/gguf/scripts/     # gguf_dump, gguf_set_metadata, gguf_new_metadata, gguf_hash, gguf_convert_endian, gguf_editor_gui
```

Use `gguf_new_metadata.py`/`gguf_set_metadata.py` for small metadata fixes (for example a chat template) instead of reconverting; read each script's `--help` first. For recipe-level changes use `llama-quantize --override-kv`.

## Upload with the Hugging Face CLI

```bash
hf auth whoami                                   # confirm identity; token comes from env/cache, never printed
hf upload <user>/<model>-GGUF ./out . --repo-type model
hf upload <user>/<model>-GGUF ./out/m-Q4_K_M.gguf m-Q4_K_M.gguf     # a single file
```

Usage per the CLI docs: `hf upload [repo_id] [local_path] [path_in_repo]`; run `hf upload --help` for options (`--repo-type`, `--include`, `--commit-message`, private repos). The Hub reads GGUF metadata and shows a tensor/metadata viewer for GGUF files ([docs](https://huggingface.co/docs/hub/gguf)).

## Model card checklist

- Source model and revision, license, and a note that this is a derivative.
- llama.cpp tag or commit (`git describe --tags`), exact convert/imatrix/quantize commands.
- imatrix: dataset description, token count, chat/special-token handling, and the file itself.
- Table: type, file size, bits/weight, Mean KLD or perplexity vs 16-bit, test text.
- Chat template and sampling guidance from the source card; the `mmproj` file and how to pass it.
- Known limits (context length tested, architectures needing a minimum llama.cpp version).

## Hosted alternative

[GGUF-my-repo](https://huggingface.co/spaces/ggml-org/gguf-my-repo) builds quants in the browser. It gives you fewer recipe controls and no KLD table; use it for quick public models only.
