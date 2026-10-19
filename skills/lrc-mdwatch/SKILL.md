---
name: lrc-mdwatch
description: Use when `mdwatch` is on PATH on Lawrencium and a task waits for or reacts to SLURM jobs - waiting for sbatch jobs to end, reading job events, STALLED or NEAR_TIMEOUT events, a FAILED, TIMEOUT, OUT_OF_MEMORY or NODE_FAIL job, `mdwatch wait` exiting 1 or 124, or keeping a watcher alive across agent sessions. General submission rules are in `lrc-cluster`.
license: MIT
compatibility: Requires a Lawrencium (LBL LRC) account in the nano group; SLURM, Lmod and bash.
---

# mdwatch on Lawrencium

[mdwatch](https://github.com/roncofaber/mdwatch) polls your jobs every minute from a user timer and writes one JSON event per state change to `~/.local/state/mdwatch/events/`: SUBMITTED, STARTED, REQUEUED, NEAR_TIMEOUT (90% of walltime), STALLED (opt-in), then the terminal state (FINISHED, FAILED, TIMEOUT, CANCELLED, OUT_OF_MEMORY, NODE_FAIL, ...). Terminal events carry the workdir, output paths, `time_used`, `cpu_efficiency` and `max_rss`: use them to size `--time` and `--mem`.

Install once per user: `/global/home/groups/nano/share/mdwatch/bin/mdwatch install`, then `mdwatch status`.

## Waiting for jobs

```bash
mdwatch wait JOBID... --timeout SECONDS   # one "JOBID STATE" line per job
mdwatch events 20                         # last 20 transitions
mdwatch show JOBID 60                     # latest event, workdir, last 60 lines of stdout/stderr
```

- Run `mdwatch wait` as a background command (in Claude Code, Bash with `run_in_background`), never in the foreground: the tool timeout kills it long before an MD job ends. Set `--timeout` above the job's expected duration.
- Exit 0: every job FINISHED. 1: at least one did not; run `mdwatch show` for each and read its diagnosis log (below) before investigating. 124: timeout with jobs still running.
- Never sleep-poll `squeue` or `mdwatch events`.

## Long-lived watchers

Agent background commands can die silently, with no output and no notification. Make nothing depend on the agent noticing in time:

- Never make a submission wait on the agent. Dependent stages go in one job; a submission that waits for free nodes goes in the queue of a detached `node_window.sh -q` (`lrc-nodes`).
- Start anything that must outlive the session with `setsid nohup ... > /dev/null 2>&1 &`.
- A background `mdwatch wait` is only a wake-up call; the record is `mdwatch events` and the watcher logs.
- At the start of every turn run `bash scripts/watchers.sh [WATCHER_LOG...]` (this skill's folder): it lists running waits and watchers, the last job events and the log tails. Re-attach any wait that died.

## Per-job options

Set in the job comment: `sbatch --comment=mdwatch:stall=30 ...` emits STALLED when nothing under the workdir or the job's output changed for 30 minutes. If the program writes outside the submit directory, add `watch=PATH`, or the job is falsely reported STALLED. `agent=off` skips the diagnosis agent, `notify=off` silences push notifications, `off` ignores the job.

## Failure diagnosis (optional)

Copy `/global/home/groups/nano/share/mdwatch/examples/opencode-agent.sh` to `~/.config/mdwatch/hooks.d/20-opencode-agent.sh` and set `MDWATCH_AGENT_MODEL` in `~/.config/mdwatch/config.env`; it needs [opencode](https://opencode.ai) with a configured provider. On FAILED, TIMEOUT, OUT_OF_MEMORY, NODE_FAIL, BOOT_FAIL and STALLED it runs a read-only diagnosis (no edits, submissions or cancels; one per batch failing for the same cause) and writes `~/.local/state/mdwatch/agent_logs/<time>_<jobid>_<state>.log`.
