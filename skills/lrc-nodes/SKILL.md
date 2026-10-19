---
name: lrc-nodes
description: Use when a Lawrencium (LRC) job is pending (Resources, Priority) or needs several free nodes at once, when choosing which etna partition can start a job now, when sinfo shows idle*, drain or down nodes, when a node fails jobs or runs slower than its peers while SLURM reports it healthy, or when keeping an excluded-nodes list. General sbatch rules are in `lrc-cluster`.
license: MIT
compatibility: Requires a Lawrencium (LBL LRC) account in the nano group; SLURM, Lmod and bash.
---

# Free, slow and excluded nodes on Lawrencium

Scripts are in this skill's `scripts/` folder; run them with `bash`, and `-h` prints their usage. They skip the excluded nodes (below).

| Script | Does |
|---|---|
| `free_nodes.sh [PARTS]` | usable idle nodes, other states, pending jobs and free GPUs per partition |
| `node_window.sh -n N ...` | waits for N usable idle nodes of one partition, then runs queued submissions |
| `node_bench.sh submit\|report` | A/B compute benchmark of a suspect node against a good one |

## Where a job can start now

Run `bash scripts/free_nodes.sh`. Only `idle=` nodes can start a job now (`sinfo -t idle` also lists unusable `idle*` nodes); `sinfo -R -p PARTITION` gives the reasons for the unavailable ones.

etna is often full, with many nodes drained. When it has no idle nodes, submit to `etna_bigmem` or `etna_c40` instead of queueing on `Priority`, and note the partition, since throughput differs.

## Waiting for N free nodes

For a job that needs N nodes of one partition, start the watcher detached instead of polling:

```bash
setsid nohup bash scripts/node_window.sh -n N -p etna,etna_bigmem,etna_c40 -q QUEUE -l LOG > /dev/null 2>&1 &
```

`QUEUE` holds one shell command per line; write it before starting the watcher, which exits when the queue is empty. Each time N usable nodes are idle, it runs the first line with `WINDOW_PARTITION` and `WINDOW_NODES` set, removes it and logs its output and exit code. Append lines while it runs; one watcher serves every waiting job in order.

Let the watcher submit, not the agent: an agent session can die before the window opens (`lrc-mdwatch`).

## Slow or failing nodes

- A node can pass SLURM, scratch and SMT checks and still run MD 1.5-2x slower. Benchmark it against a known-good node of the same partition with `bash scripts/node_bench.sh submit PARTITION SUSPECT GOOD` (about a minute each), then `bash scripts/node_bench.sh report`: a node marked `DEGRADED` (more than 25% below the best) goes in your excluded-nodes list.
- Users cannot ssh to compute nodes. `scontrol show node n0047.etna0` (full hostname) shows `ThreadsPerCore=1` when SMT is off.
## Excluded nodes

- The nano group shares one list, `/global/home/groups/nano/share/excluded_nodes`: one node per line with a `#` comment saying who, when and why. Every script here and in `lrc-cluster` (`xbatch.sh`) and the CoMoDInO submit scripts skip those nodes.
- Add a node only after it failed a job while SLURM reported it healthy, or after `node_bench.sh` marked it `DEGRADED`, and ask the user first: the list changes every member's jobs. Remove it once a benchmark pair shows it healthy again.
- `EXCLUDE_NODES_FILE=FILE` uses another list instead; `EXCLUDE_NODES_FILE=` excludes nothing. `bash` `excluded_nodes.sh` (`lrc-cluster`) prints the list in effect.
