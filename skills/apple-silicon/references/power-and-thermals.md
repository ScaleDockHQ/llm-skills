# Power and thermals

> Verified against macOS 26.6 man pages (`pmset`, `caffeinate`, `powermetrics`) and local runs of the read-only commands, llama-bench README (b11557), 2026-10-11

Facts here come from macOS tooling observed on the machine; sustained-throttling behaviour per model is community knowledge.

## Read state (no sudo)

```bash
pmset -g therm                      # "No thermal warning level has been recorded" is the healthy output
pmset -g batt | head -2             # AC or battery
pmset -g | grep lowpowermode        # prints 1 when Low Power Mode is on
```

## Rules

- Fanless MacBook Air models throttle during sustained generation; MacBook Pro, Mac mini and Mac Studio hold clocks longer (community). Expect decode to drop over a long run on fanless machines.
- On battery macOS may lower performance; in Low Power Mode numbers are not comparable. Benchmark on AC, outside Low Power Mode.
- Benchmark with fixed lengths and a cool-down gap. `llama-bench` has `-r` (repetitions, default 5), `--delay` (seconds between tests) and `-p`/`-n`; use `scripts/bench.sh` from `local-llms` for an end-to-end server benchmark (install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`).
- Close memory-heavy apps first; thermal and memory pressure compound.

```bash
llama-bench -m model.gguf -p 512 -n 128 -r 3 --delay 30 -o md   # fixed lengths, cool-down between tests
```

## Watch GPU power and frequency (needs sudo, read-only)

```bash
sudo powermetrics --samplers gpu_power -i 1000 -n 5
```

Ask before running it; it only samples. Throttling shows as GPU frequency falling during a long generation while `pmset -g therm` starts reporting warnings.

## Sleep during a long job

`caffeinate -i <command>` keeps the system from idle sleep for the lifetime of the command (`-s` only on AC power, `-d` keeps the display on). Use it for one-off jobs; for an always-on server see `operating.md`.
