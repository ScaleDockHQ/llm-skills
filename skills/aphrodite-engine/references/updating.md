# Aphrodite Engine updating

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

Releases: v0.22.0 2026-07-19, v0.23.0 2026-07-31, v0.24.0 2026-09-08, v0.24.1 2026-09-11. Release notes are
commit lists with many `[sync]` vLLM ports: `gh release view vX.Y.Z -R dphnAI/sonar`. There is no migration
guide beyond the upgrading page, so test.

1. Record version, commit, model and tokenizer revisions, PyTorch and CUDA versions and the full command
   (`aphrodite --version`, `uv pip freeze | grep -Ei 'aphrodite|torch|flashinfer'`).
2. Save representative requests with expected properties (not exact text).
3. Fresh venv when core dependencies change; keep the old one for rollback.
   `uv pip install --upgrade "aphrodite-engine==X.Y.Z" --torch-backend=cu130`.
   Source: `git fetch && git switch main && git pull --ff-only && uv pip install --editable .`; regenerate the
   CMake preset when Python, CUDA, compiler or venv change.
4. Compare startup warnings and the generated server-argument reference with the saved command (renamed flags).
5. Test chat, streaming, structured output, tools, LoRA, multimodal; compare latency and memory with baseline.
6. Roll back by restoring the old venv or image and model revision; remove the failed replica from traffic first.
   Loader or symbol errors after rollback: separate compile cache keys per stack.

The project rename (Aphrodite to Sonar, repository and docs moved) changed branding, banner and URLs only; the
package and command names did not change as of v0.24.1.
