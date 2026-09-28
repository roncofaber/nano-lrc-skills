---
name: lrc-mdwatch
description: Use mdwatch, the SLURM job watcher shared with the nano group on Lawrencium, to wait for jobs, read job events, detect stalled MD runs and read automatic failure diagnoses. Use when mdwatch is on PATH and the task involves waiting for or reacting to sbatch jobs, STALLED or NEAR_TIMEOUT events, or a failed job. For general submission rules use `lrc-cluster`.
---

# mdwatch on Lawrencium

mdwatch (github.com/roncofaber/mdwatch) polls all of your jobs every minute from a systemd user timer and writes one JSON event per transition to `~/.local/state/mdwatch/events/`: SUBMITTED, STARTED, REQUEUED, NEAR_TIMEOUT (90% of walltime), STALLED (opt-in), then the terminal state. Terminal events carry workdir, stdout/stderr paths, `time_used`, `cpu_efficiency` and `max_rss`; use those to size `--time` and `--mem`. Never sleep-poll `squeue`.

## Install (once per user)

```bash
/global/home/groups/nano/share/mdwatch/bin/mdwatch install
```

It links `~/.local/bin/mdwatch`, writes your config to `~/.config/mdwatch/config.env` and installs a cron entry or, where crontab is disabled, a systemd user timer. Your jobs, events and hooks stay in your own home.

## Use

```bash
mdwatch wait JOBID... --timeout 3600   # block until the jobs end; exit 0 only if all FINISHED
mdwatch events 20                      # last 20 transitions, one line each
mdwatch show JOBID 60                  # event JSON, workdir and the last 60 lines of stdout/stderr
```

Per-job options go in the job comment: `sbatch --comment=mdwatch:stall=30 ...` emits STALLED when nothing under the workdir or the job's output changed for 30 minutes (useful for long MD runs, where a hung MPI job otherwise burns walltime until TIMEOUT). `watch=PATH` watches another directory than the job's workdir, `agent=off` skips the diagnosis agent, `notify=off` silences pushes, `off` ignores the job.

## Failure diagnosis hook (optional)

`examples/opencode-agent.sh` in the mdwatch checkout, installed as `~/.config/mdwatch/hooks.d/20-opencode-agent.sh`, starts a headless read-only opencode diagnosis on FAILED, TIMEOUT, OUT_OF_MEMORY, NODE_FAIL, BOOT_FAIL and STALLED. The agent can read files and run `sacct`/`squeue`/`mdwatch show` but cannot edit, submit or cancel. Set the model with `MDWATCH_AGENT_MODEL` in `config.env`. Results go to `~/.local/state/mdwatch/agent_logs/<time>_<jobid>_<state>.log`; read that log before investigating a failure from scratch. Agents run one at a time and a batch of jobs failing for one cause gets one shared diagnosis.
