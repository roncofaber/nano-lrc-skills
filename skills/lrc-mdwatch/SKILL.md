---
name: lrc-mdwatch
description: Use mdwatch, the SLURM job watcher shared with the nano group on Lawrencium, to wait for jobs, read job events, detect stalled MD runs and read automatic failure diagnoses. Use when mdwatch is on PATH and the task involves waiting for or reacting to sbatch jobs, STALLED or NEAR_TIMEOUT events, or a failed job. For general submission rules use `lrc-cluster`.
---

# mdwatch on Lawrencium

mdwatch (github.com/roncofaber/mdwatch) polls all of your jobs every minute from a systemd user timer and writes one JSON event per transition to `~/.local/state/mdwatch/events/`: SUBMITTED, STARTED, REQUEUED, NEAR_TIMEOUT (90% of walltime), STALLED (opt-in), then the terminal state (FINISHED, FAILED, TIMEOUT, CANCELLED, OUT_OF_MEMORY, NODE_FAIL, ...). Terminal events carry workdir, stdout/stderr paths, `time_used`, `cpu_efficiency` and `max_rss`; use those to size `--time` and `--mem`.

## Install (once per user)

```bash
/global/home/groups/nano/share/mdwatch/bin/mdwatch install
mdwatch status
```

It links `~/.local/bin/mdwatch`, writes `~/.config/mdwatch/config.env` and schedules the watcher (cron, or a systemd user timer where crontab is disabled). Your jobs, events and hooks stay in your own home.

## Waiting for jobs

`mdwatch wait` blocks until every listed job ends. Run it as a background command (in Claude Code, Bash with `run_in_background`), never in the foreground: a foreground wait ties up the session and is killed by the tool timeout long before an MD job ends. You are notified when it exits; then read its output.

```bash
mdwatch wait JOBID... --timeout 86400   # background; one "JOBID STATE" line per job
```

Exit 0 means every job FINISHED, 1 means at least one ended otherwise, 124 means the timeout passed with jobs still running. On 1, the output lines name the jobs that did not finish: run `mdwatch show` for each and, if the diagnosis hook is installed (`ls ~/.config/mdwatch/hooks.d`), read its log (below) before investigating.

```bash
mdwatch events 20       # last 20 transitions, one line each
mdwatch show JOBID 60   # latest event JSON, workdir and the last 60 lines of stdout/stderr
```

Size `--timeout` above the job's expected duration (a 20 ns metadynamics suite runs about 45-50 h on etna; use 60 h, i.e. 216000 s). Never sleep-poll `squeue` or `mdwatch events` in a loop.

## Long-lived watchers in agent sessions

Agent background commands are not reliable hosts for waits of more than a few hours: on Lawrencium they have died silently, with no output and no notification, three times in one campaign, once missing a node window by 2 h. Design so nothing depends on the agent noticing in time:

- Never make a submission wait on the agent. Stages that follow each other go in one job (`comodino-campaigns`: `submit_suite.sh SUITE wall_ramp,wall_relax,metadynamics`), and a submission that waits for free nodes goes in the queue of a detached `node_window.sh -q` (`lrc-cluster`), which submits it itself when the window opens.
- Start anything that must outlive the session detached: `setsid nohup bash node_window.sh ... -l LOG > /dev/null 2>&1 &`. It inherits your environment, keeps running when the agent dies, and writes every reading to its log.
- A background `mdwatch wait` is only a wake-up call. The record is mdwatch's event store (`mdwatch events`) and the watcher's log, which persist whatever happens to the agent; ntfy also pushes every job event to the user.
- At the start of every turn, list your watchers with `ps -u $USER -o pid,etime,args | grep -E 'mdwatch wait|node_window'` and read `mdwatch events 20` and the watcher log tails. Re-attach any wait that died; do not assume a silent background command is still running.

## Per-job options

Options go in the job comment: `sbatch --comment=mdwatch:stall=30 ...` emits STALLED when nothing under the workdir or the job's output changed for 30 minutes, so a hung MPI job does not burn walltime until TIMEOUT. If the program writes outside the submit directory, add `watch=PATH`, or every job is falsely reported STALLED. `agent=off` skips the diagnosis agent, `notify=off` silences pushes, `off` ignores the job.

## Failure diagnosis hook (optional)

`/global/home/groups/nano/share/mdwatch/examples/opencode-agent.sh`, copied to `~/.config/mdwatch/hooks.d/20-opencode-agent.sh`, starts a headless read-only [opencode](https://opencode.ai) diagnosis on FAILED, TIMEOUT, OUT_OF_MEMORY, NODE_FAIL, BOOT_FAIL and STALLED. It needs opencode with a configured provider (CBorg works) and `MDWATCH_AGENT_MODEL` in `config.env`. The agent can read files and run `sacct`/`squeue`/`mdwatch show` but cannot edit, submit or cancel. A batch of jobs failing for one cause gets one shared diagnosis. Results go to `~/.local/state/mdwatch/agent_logs/<time>_<jobid>_<state>.log`.
