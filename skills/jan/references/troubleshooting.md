# Jan: troubleshooting

> Verified against Jan v0.8.6 (docs jan.ai/docs/desktop), 2026-10-11

Sources: jan.ai/docs/desktop troubleshooting, api-server, custom-endpoint, mlx; v0.8.5 and v0.8.6 changelogs. Logs: `<data folder>/logs/app.log`, look for `[APP]`, `[SERVER]`, `[llamacpp-router]`.

| Symptom                                                                   | Likely cause                                                       | Fix                                                               |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------ | ----------------------------------------------------------------- |
| Connection refused on 1337                                                | Server not started, wrong host/port, Jan closed (background off)   | Start the server; `lsof -nP -iTCP:1337`                           |
| Server will not bind                                                      | Port 1337 held by a stale Jan process; no auto fallback            | Quit the process or change the port                               |
| 401 Unauthorized                                                          | API key missing or wrong                                           | `Authorization: Bearer` (or `x-api-key` for `/v1/messages`)       |
| 403 from LAN or container                                                 | `0.0.0.0` bind and Host not trusted (v0.8.5+)                      | Add the name to Trusted Hosts                                     |
| 404                                                                       | Model ID mismatch or wrong API prefix; custom base URL lacks `/v1` | `GET /v1/models`; fix the URL                                     |
| Browser CORS error                                                        | CORS toggle off                                                    | Enable CORS                                                       |
| Model will not load                                                       | Wrong backend or memory; new architecture; GPU driver              | Smaller or more quantized model, check logs; for MLX use the GGUF |
| Linux AppImage crashes on model load                                      | v0.8.5 bundled Vulkan loader                                       | Update to v0.8.6                                                  |
| CUDA "PTX compiled with an unsupported toolchain" on GTX 16xx or RTX 20xx | Fixed in v0.8.6                                                    | Update                                                            |
| Generation slow after 0.8.5, 12 GB GPU, MTP model                         | Parallel Sequences auto reserves slots                             | Lower Parallel Sequences                                          |
| Local models fail on Intel Mac                                            | Engine is Apple Silicon only from v0.8.5                           | Stay on v0.8.4 or use remote providers                            |
| Jan will not start                                                        | Corrupt `store.json` or a running instance                         | Quit Jan, rename `store.json`; check tray/ps                      |
| Broken build after install                                                | Corrupt app data                                                   | Uninstall, delete the app data folder (back up first), reinstall  |
| MCP tool not called                                                       | Model lacks tool capability                                        | Enable tools in model capabilities                                |
