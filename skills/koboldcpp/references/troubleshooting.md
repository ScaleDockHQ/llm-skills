# KoboldCpp troubleshooting

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

Capture the exact error, the full launch flags and `--version`. Add `--debugmode` and relaunch.

| Symptom                              | Cause                                                  | Fix                                                                                                                                                                      |
| ------------------------------------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Browser cannot connect               | Model still loading, other port, bound to another host | Wait for the load message; check the printed address; default is port 5001                                                                                               |
| Port already in use                  | Another instance                                       | `ss -ltnp \| grep 5001`; use `--port`; `--singleinstance` lets a new instance replace the old                                                                            |
| Crash at startup on an older machine | No AVX2 or newer instructions                          | `--noavx2`, the `oldpc` build, `--failsafe`                                                                                                                              |
| Model will not load                  | Not enough memory, unsupported model for this version  | Check the terminal error; smaller quant or context; try the latest release; check the wiki or file an issue with OS, hardware, version, model file name, flags and error |
| GPU out of memory                    | Context or layers too large; autofit is an estimate    | Lower `--gpulayers`, `--contextsize`, use `--quantkv`, raise `--autofitpadding`                                                                                          |
| System out of RAM                    | Large model or context                                 | Smaller model or context; raise GPU layers                                                                                                                               |
| Generation slow                      | CPU backend, no offload                                | Select `--usecuda` or `--usevulkan`; check `--gpulayers`; run `--benchmark`                                                                                              |
| Incoherent or looping output         | Wrong chat template                                    | `--jinja`, or set `--chatcompletionsadapter`; check sampler defaults                                                                                                     |
| Tool calls ignored or malformed      | Template without tool support                          | `--jinja --jinja_tools`, a tool-capable model                                                                                                                            |
| Thinking text in answers             | Reasoning model                                        | `--jinjathink false` or `--reasoningeffort none`                                                                                                                         |
| 401 Unauthorized                     | `--password` set                                       | Send `Authorization: Bearer <key>`                                                                                                                                       |
| Image endpoint works without key     | Not covered by `--password`                            | Enforce auth at a reverse proxy                                                                                                                                          |
| Requests queue or time out           | Single generation slot                                 | `--parallelrequests N`, `--reqtimeout`, or a different engine for concurrency                                                                                            |
| Router mode ignores model name       | Not in `--admindir`, or router off                     | File must be listed by `/api/admin/list_options`; use `--admin --admindir --routermode`                                                                                  |
| macOS blocks the binary              | Gatekeeper                                             | Allow in Privacy & Security                                                                                                                                              |
| Launcher GUI fails on a headless box | Tk missing                                             | `--skiplauncher` with `--model`                                                                                                                                          |
| Docker performs badly or fails       | Unsupported host (Windows, macOS, ARM)                 | Use the prebuilt binaries                                                                                                                                                |

Read-only diagnostics:

```bash
curl -s http://127.0.0.1:5001/api/extra/version | jq .
curl -s http://127.0.0.1:5001/api/extra/perf | jq .
./koboldcpp-linux-x64 --analyze model.gguf | head -40
```
