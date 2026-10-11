# EXL3 quantization: updating ExLlamaV3 and redoing quants

> Verified against exllamav3 v1.6.1, 2026-10-11

ExLlamaV3 releases fast (v1.5.4 on 2026-10-03, v1.6.0 on 2026-10-07, v1.6.1 on 2026-10-10), and TabbyAPI enforces the matching library version at runtime. Converter and server versions should stay compatible.

```bash
gh release list -R turboderp-org/exllamav3 -L 5           # read the notes of anything newer than your pin
python3 -c "import exllamav3;print(exllamav3.__version__)"
cd ~/src/exllamav3 && git fetch --tags && git checkout <new-tag>
pip install <wheel or: pip install --no-build-isolation .>    # install method per the exllamav3 skill
python convert.py -h | head -40                             # flags change between versions
```

## What to redo

- Existing EXL3 outputs keep loading in newer versions in the usual case; read the release notes for format changes before assuming.
- Requantize when: the notes mention a quantizer fix or new default (for example codebook, scales, head bits), your architecture's support was improved, or an architecture you needed was added.
- Resumed jobs restore their settings from the work dir; a version change mid-job is not supported ((unverified)), so finish or restart the job on one version.
- Keep the old checkout and venv until the new outputs pass `references/evaluation.md`.
- Record the new version in the model card and branch notes.
