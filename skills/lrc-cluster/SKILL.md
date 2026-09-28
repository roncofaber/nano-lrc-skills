---
name: lrc-cluster
description: Operate on the LBL Lawrencium HPC cluster (LRC, SLURM) as a nano group member, especially the etna partitions. Use when writing or submitting sbatch scripts, checking squeue or sinfo, choosing partitions or accounts, laying out scratch project folders, binding MPI ranks, loading Lmod modules from the nano group tree, building software, or planning GPU runs on LRC. For LAMMPS use `lrc-lammps`; for job events and failure diagnosis use `lrc-mdwatch`; for CoMoDInO campaigns use `comodino-campaigns`.
---

# Lawrencium (LRC) cluster operations for nano users

Operational conventions for nano group members running calculations on the LBL Lawrencium cluster (LRC). Follow them unless the user says otherwise. Recheck node counts and GPU health with `sinfo` before planning around them.

## Cluster identity

- SLURM 25.05, Rocky 8, Lmod. Main MD partition: `etna` (24-core nodes, 2 sockets, 64 GB RAM). GPU nodes: `etna_gpu` (8 cores, 2x V100 16 GB, 192 GB RAM; the K80 nodes are all down or drained).
- `crontab` and `scrontab` may be disabled for your account. Run recurring tasks as systemd user timers (`systemctl --user list-timers`); they survive logout only with linger enabled (`loginctl show-user $USER -p Linger`).

## Data layout and folder conventions

- Long-lived project data lives on scratch, `/global/scratch/users/$USER/<NN_program>/<NN_project>/<NN_campaign>/` (often linked as `~/HPC_SCRATCH`), every level zero-padded in stage order, e.g. `20_CModel/21_comodino_agentic_v2/01_nacl_au111`.
- Work inside a campaign gets numbered step folders (`00_pilot`, `01_staged_bulk`, `02_bench`, ...): builder outputs, staged bundles, benchmarks, chains each in their own numbered folder, series subdirectories keyed by the varying quantity (`01_4pairs`, `02_10pairs`, ...).
- Every new folder gets a zero-padded numeric prefix in stage order: `01_`, `02_`, ... No duplicate prefixes.
- Never rerun into existing output prefixes.
- NEVER rename directories that running jobs use. Renaming a process cwd keeps cwd-relative file IO alive (inode-based), but OpenMPI process spawning re-resolves the cwd by path and dies at the next mpirun with "Open RTE was unable to initialize properly ... attempting to get the cwd. Returned value -11". Rename only after all jobs in the tree finished.
- Document conventions and operational findings in the project `AGENTS.md` as they appear.

## Agent autonomy

- Once working on a cluster task, agents may submit, poll and cancel sbatch jobs freely; no per-job approval is needed for the free partitions below.
- Billing partitions (everything marked paid below) need explicit user confirmation before any submission.
- Automate multi-step work inside one job (a chain script or an upstream runner such as `comodino.md.execution.chain`) rather than having an agent resubmit one step per job. Per-step resubmission wastes queue time and races with the files each step writes; react when the whole job ends (`lrc-mdwatch` if you use mdwatch).

## Partitions and accounts

| Partition | Account | Cost | Use |
|-----------|---------|------|-----|
| `etna`    | `nano`  | free, preferred | CPU MD work (24-core, 64 GB nodes) |
| `etna_gpu` | `nano` | free | V100 GPU runs (driver 580, sm_70) |
| `dirac1`  | `dirac1` | free | also accessible; the `nano` account is rejected here |
| `etna_bigmem`, `etna_c40` | `nano` | free | 32-core/95 GB and 40-core/96 GB etna nodes; adjust `--ntasks` to the core count |
| `es0`, `es1`, `es2` | `ac_nanotheory` | paid | GPU resources (es0 RTX 2080 Ti; es1 A40, A100, V100, RTX 8000; es2 H100, H200); ask before using |
| other LRC partitions (`lr*`, `cf1`, `cm*`, `vulcan*`, `nano1`, ...) | - | paid or unverified | explicit confirmation required |

- QOS: `normal` for every free partition. List your associations with `sacctmgr -nP show assoc user=$USER format=account,partition,qos`.
- Many etna nodes sit in `drain`/`down`. `sinfo -p etna -R` lists the reasons; `sinfo -p etna -t idle` shows what is free now.

## Queue checking

```bash
sinfo -p etna,etna_bigmem,etna_c40 -h -o "%.12P %.10t %.4D"   # alloc/idle nodes per partition
squeue -u $USER                                             # your jobs
sinfo -p etna -R                                            # why nodes are drained or down
```

## Job events

Never sleep-poll `squeue` in a loop. If `mdwatch` is on your PATH, use it (see `lrc-mdwatch`); otherwise let the job itself do the multi-step work and check back later.

## Job submission

- Check where the job can actually start before submitting: `sinfo -p etna,etna_bigmem,etna_c40 -h -o "%.12P %.10t %.4D"` shows alloc/idle per partition. etna is often fully allocated with the rest drained/down; when it has no idle nodes, submit to `etna_bigmem` or `etna_c40` instead of queueing on `Priority`, and say so in the job name or notes since throughput differs.
- Submit with `sbatch` in the background. Never hold interactive `salloc` sessions for real work; they block the session and die with it.
- One job per submit per configuration. Never loop many rank counts or parameter points sequentially inside one allocation; submit independent jobs instead (etna usually has idle nodes).
- Exclude known-bad nodes when they fail jobs while SLURM still reports them healthy: keep the list in a file and submit with `sbatch -x "$(<FILE)" [options] script.sh`. Personal wrappers around this belong in your own dotfiles.
- Standard CPU header: `--account=nano --partition=etna --qos=normal --exclusive`, one task per rank (`--ntasks=N --cpus-per-task=1`), bounded `--time`.

## sbatch gotchas

- SLURM spools the batch script: `BASH_SOURCE[0]`-based `cd` lands in a spool directory, not the submit directory. Use `cd "${SLURM_SUBMIT_DIR:-$(pwd)}"`.
- `/tmp` is node-local. `--output=/tmp/...` writes on the compute node and the file never appears on the login node; send output to the submit directory or scratch.
- OpenMPI reads slots from the SLURM allocation: `--ntasks=1 --cpus-per-task=24` gives `mpirun -np 4` a "not enough slots" error. Allocate `--ntasks=N`, one per rank.
- `sbatch --export=VAR=x` REPLACES the exported environment (PATH, SLURM vars, HOME get stripped; multi-node orted daemons then fail). Append instead: `--export=ALL,VAR=x`.
- Variables passed via `--export` resolve against `SLURM_SUBMIT_DIR` inside the job, not the submission shell's cwd. Pass absolute paths (e.g. SYSTEM_DIR) or make the script's `cd` chain consistent with them.
- Module load state does not persist between shell sessions; always load modules inside the same script that uses them.
- Size `--time` from measured throughput, not step counts alone: the ~6k-atom bulk chain (5.52M steps at 0.5 fs) runs in about 7.5 h at 204 steps/s on one 24-rank node, so 12 h fits it with margin. Larger interface systems are slower; measure before sizing. Support resume via a `START_STAGE` variable (checked against the stage list) so an interrupted chain restarts from the last completed stage's restart file.

## MPI binding is mandatory on etna

The flags below are OpenMPI syntax; for Intel MPI builds use `I_MPI_PIN=1 I_MPI_PIN_DOMAIN=core` and verify with `I_MPI_DEBUG=4`. Unbound ranks cost 14x at 4 ranks (uniform slowdown in communication-heavy sections, local compute unaffected). Forcing shared-memory transports does not help.

```bash
mpirun --bind-to core --map-by core -np N <exe> -in input -screen none
```

For small and medium runs also set `OMP_NUM_THREADS=1` and `MKL_NUM_THREADS=1` (library threading otherwise oversubscribes the node).

## References

Read only when the task needs it.

- [assets/etna_cpu.sbatch](assets/etna_cpu.sbatch): starting point for a free-partition CPU job with the header, submit-dir `cd`, thread pinning, and bound `mpirun` already applied. Replace the uppercase placeholders; submit with `sbatch` (add `-x <bad-nodes>` when needed).
- [references/software.md](references/software.md): Lmod module paths, Python environments, building and installing software, and GPU compatibility caveats.
