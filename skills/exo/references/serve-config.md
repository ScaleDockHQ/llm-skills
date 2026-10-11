# exo: flags, ports and environment

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: README "Environment Variables" and "Configuration Options", `src/exo/main.py`. Run `uv run exo --help` for the installed version.

## CLI flags

| Flag                               | Meaning                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| `-v` / `-q`                        | More or less log output                                                              |
| `-m`, `--force-master`             | Raise this node's election seniority so it becomes master                            |
| `--no-api`                         | Do not start the HTTP API on this node                                               |
| `--api-port N`                     | API port, default 52415                                                              |
| `--no-worker`                      | Coordinator only: networking and orchestration, no inference                         |
| `--no-downloads`                   | Disable the download coordinator on this node                                        |
| `--offline`                        | Air-gapped mode, only pre-staged local models (also `EXO_OFFLINE=true`)              |
| `--no-batch`                       | Disable continuous batching, generate sequentially                                   |
| `--legacy-daemon`                  | SysV double-fork daemon; not for systemd or launchd                                  |
| `--bootstrap-peers a,b`            | Comma-separated peers to dial (also `EXO_BOOTSTRAP_PEERS`)                           |
| `--namespace NAME`                 | Discovery namespace; defaults to the exo version, different namespaces never connect |
| `--zenoh-port N`                   | Fixed TCP port for zenoh, default 52414                                              |
| `--discovery-port N`               | Fixed UDP discovery port, default 52413                                              |
| `--fast-synch` / `--no-fast-synch` | Force MLX FAST_SYNCH on or off (JACCL backend)                                       |

## Environment variables

| Variable                    | Meaning                                                          | Default                                                      |
| --------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------ |
| `EXO_DEFAULT_MODELS_DIR`    | First writable model directory                                   | `~/.local/share/exo/models` (Linux), `~/.exo/models` (macOS) |
| `EXO_MODELS_DIRS`           | Extra writable dirs, colon-separated; first with free space wins | none                                                         |
| `EXO_MODELS_READ_ONLY_DIRS` | Pre-downloaded models (NFS, shared); cannot be deleted from exo  | none                                                         |
| `EXO_OFFLINE`               | No internet                                                      | `false`                                                      |
| `EXO_ENABLE_IMAGE_MODELS`   | Image model support                                              | `false`                                                      |
| `EXO_LIBP2P_NAMESPACE`      | Cluster isolation namespace                                      | none                                                         |
| `EXO_FAST_SYNCH`            | MLX_METAL_FAST_SYNCH behavior                                    | auto                                                         |
| `EXO_TRACING_ENABLED`       | Distributed tracing                                              | `false`                                                      |

## Ports to open between nodes

API 52415/tcp, zenoh 52414/tcp, discovery 52413/udp (defaults from `main.py`). Check what is listening: `lsof -nP -iTCP:52414-52415 -sTCP:LISTEN`.
