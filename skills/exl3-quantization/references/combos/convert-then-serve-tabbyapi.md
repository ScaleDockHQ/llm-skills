# EXL3 quantization with TabbyAPI

> Verified against exllamav3 v1.6.1 and TabbyAPI main (config_sample.yml, docs), 2026-10-11

Convert a model, check it, and serve it for a smoke test.

```bash
# 1. convert
cd ~/src/exllamav3
python convert.py -i ~/models/<model> -o ~/models/exl3/<model>-4.0bpw -w ~/scratch/exl3-work -b 4.0 -hq

# 2. compare with the original
python eval/model_diff.py -ma ~/models/exl3/<model>-4.0bpw -mb ~/models/<model> -r 50 -l 2048

# 3. serve (TabbyAPI config.yml: model.model_dir=~/models/exl3, model.model_name=<model>-4.0bpw)
curl -s http://127.0.0.1:5000/health
```

TabbyAPI install, authentication, `config.yml` keys, `--shm-size` for containers and port exposure are in the `exllamav3` skill. Keep the API on loopback unless you add auth; do not print the keys in `api_tokens.yml`.

## Pitfalls

- TabbyAPI and the converter must use the same exllamav3 version family; check before comparing numbers.
- Do not convert and serve on the same GPU at once.
- Delete `~/scratch/exl3-work` only after the output passed the checks.
