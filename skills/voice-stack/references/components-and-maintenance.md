# Components, licences and maintenance status

> Verified against the GitHub repositories and latest releases of each project, 2026-10-11

Checked with the GitHub API on the writing date (archived flag, last push, latest release). Re-check before you adopt a component.

| Component                                 | Role                     | Status on 2026-10-11                                                                                                       | Licence (repo)                                                                   | Skill                                |
| ----------------------------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------ |
| whisper.cpp                               | STT                      | Active, v1.9.5 (2026-10-06)                                                                                                | MIT                                                                              | `whisper-cpp`                        |
| Kokoro-FastAPI (`remsky`)                 | TTS server for Kokoro    | Active, v0.9.0 (2026-09-10), last push 2026-10-11                                                                          | Apache-2.0                                                                       | `self-hosted-genmedia` covers it     |
| Kokoro (`hexgrad/kokoro`)                 | TTS library and model    | Not archived, last push 2025-08, no GitHub releases; the model is Kokoro-82M on Hugging Face. Treat as stable, slow-moving | Apache-2.0                                                                       | none                                 |
| Piper, original (`rhasspy`)               | TTS                      | **Archived** 2025-08-26 (last release 2023.11.14-2). Do not start new work on it                                           | MIT                                                                              | none                                 |
| Piper, successor (`OHF-Voice/piper1-gpl`) | TTS                      | Active, v1.8.0 (2026-09-04)                                                                                                | GPL-3.0                                                                          | none; check GPL fit before embedding |
| Speaches                                  | STT and TTS server       | Active repo (push 2026-10-10) but the newest release is a pre-release, v0.9.0-rc.3 (2025-12-27)                            | MIT                                                                              | `self-hosted-genmedia` covers it     |
| Open WebUI                                | Chat and Voice Mode UI   | Active, v0.12.0 (2026-10-10)                                                                                               | repo licence is custom (`NOASSERTION` in the API); read it before redistributing | `open-webui` skill later             |
| Ollama                                    | LLM server               | Active, v0.40.3 (2026-10-11)                                                                                               | MIT                                                                              | `ollama`                             |
| Pipecat                                   | Realtime agent framework | Active, v1.12.0 (2026-09-26)                                                                                               | BSD-2-Clause                                                                     | none                                 |
| LiveKit Agents                            | Realtime agent framework | Active, 1.8.6 (2026-10-09)                                                                                                 | Apache-2.0                                                                       | none                                 |
| LiveKit server                            | WebRTC server            | Active, v1.13.9 (2026-10-07)                                                                                               | Apache-2.0                                                                       | none                                 |

Notes:

- Licences are the repository licences from the GitHub API; model weights have their own terms (Kokoro-82M: check its Hugging Face card; whisper models: see the `whisper-cpp` skill).
- Use of a model licence is the user's call: surface it, do not decide it.
- Skills to install later: `open-webui`. Pipecat, LiveKit and Piper have no planned skill in this repo.

## Re-checking

```bash
for r in remsky/Kokoro-FastAPI OHF-Voice/piper1-gpl pipecat-ai/pipecat livekit/agents; do
  gh api repos/$r --jq '[.full_name,.archived,.pushed_at]|@tsv'
  gh api repos/$r/releases/latest --jq '[.tag_name,.published_at]|@tsv'
done
```
