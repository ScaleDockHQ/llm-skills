# faster-whisper: updating

> Verified against faster-whisper v1.2.1 (GitHub releases, PyPI), CTranslate2 4.8.2, 2026-10-11

## What is current

```bash
pip index versions faster-whisper 2>/dev/null | head -1      # newest on PyPI
pip list 2>/dev/null | grep -iE 'faster-whisper|ctranslate2|onnxruntime|^av '
curl -s https://pypi.org/pypi/faster-whisper/json | jq -r '.info.version, .info.requires_python'
gh api repos/SYSTRAN/faster-whisper/releases --jq '.[:5][]|[.tag_name,.published_at]|@tsv'
```

On 2026-10-11 the latest release was v1.2.1 (2025-10-31), preceded by v1.2.0 (2025-08-06) and v1.1.1 (2025-01-01). The repository itself was still receiving commits (pushed 2026-10-10), so `master` can be ahead of the last release. CTranslate2 was at v4.8.2 (2026-08-31).

## Upgrade

```bash
pip install --upgrade faster-whisper        # inside the virtualenv
python3 -c 'import faster_whisper, ctranslate2; print(faster_whisper.__version__, ctranslate2.__version__)'
```

1. Read the release notes first; defaults such as VAD parameters and batched options have changed between versions.
2. `faster-whisper` requires `ctranslate2>=4.0,<5`. A CUDA 11 or cuDNN 8 stack needs an older CTranslate2 (`install.md`), and upgrading faster-whisper alone can pull a newer one that breaks GPU loading.
3. Re-run the smoke test and your accuracy sample on the same audio before and after.

## Pin and roll back

```bash
pip freeze | grep -iE 'faster-whisper|ctranslate2' > constraints.txt
pip install 'faster-whisper==1.2.1' 'ctranslate2==4.8.2'
```

Model files are separate from the package, so rolling back the library does not touch the cache. To pin a model, pass `revision="<commit>"` to `WhisperModel` (Hub revision, tag or branch).

## Servers built on it

Speaches pins its own faster-whisper; update it by pulling a new image (`speaches` skill), not by `pip install` inside the container.
