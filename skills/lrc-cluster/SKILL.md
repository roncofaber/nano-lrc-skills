---
name: lrc-cluster
description: Operate on the LBL Lawrencium HPC cluster (LRC, SLURM) as a nano group member, especially the etna partitions. Use when writing or submitting sbatch scripts, checking squeue or sinfo, finding free nodes or GPUs, choosing partitions or accounts, binding MPI ranks, loading Lmod modules from the nano group tree, building software, or planning GPU runs on LRC. For LAMMPS use `lrc-lammps`; for job events and failure diagnosis use `lrc-mdwatch`; for CoMoDInO campaigns use `comodino-campaigns`.
---

# Lawrencium (LRC) cluster operations for nano users

Operational conventions for nano group members running calculations on the LBL Lawrencium cluster (LRC). Follow them unless the user says otherwise. Node counts and health change: check `sinfo` before planning around them.

## Cluster identity

- SLURM 25.05, Rocky 8, Lmod. Main MD partition: `etna` (24-core nodes, 2 sockets, 64 GB RAM). GPU nodes: `etna_gpu` (8 cores, 2x V100 16 GB, 192 GB RAM; the K80 nodes are down or drained).
- `crontab` and `scrontab` may be disabled for your account. Run recurring tasks as systemd user timers (`systemctl --user list-timers`); they survive logout only with linger enabled (`loginctl show-user $USER -p Linger`).
- Long-lived project data belongs on scratch, `/global/scratch/users/$USER/`, not in `$HOME`.

## Use every core of the node

One MPI rank per allocated core, on whatever partition the job lands: 24 on etna and dirac1, 32 on etna_bigmem, 40 on etna_c40 ([assets/partitions.sh](assets/partitions.sh) is the table scripts read). Never hard-code 24: request whole nodes (`--exclusive`, `--ntasks-per-node` = the partition's cores) and compute the rank count inside the job as `$(( SLURM_CPUS_ON_NODE * SLURM_NNODES ))`, as [assets/etna_cpu.sbatch](assets/etna_cpu.sbatch) does. A run may continue on a different partition: restarts do not depend on the rank count. Use fewer ranks only for a measured reason (e.g. a benchmark showing no gain), and record it.

## Partitions and accounts

| Partition | Account | Cost | Use |
|-----------|---------|------|-----|
| `etna`    | `nano`  | free, preferred | CPU MD work (24-core, 64 GB nodes) |
| `etna_gpu` | `nano` | free | V100 GPU runs (sm_70) |
| `etna_bigmem` | `nano` | free | 32-core, 95 GB etna nodes |
| `etna_c40` | `nano` | free | 40-core, 96 GB etna nodes |
| `dirac1`  | `dirac1` | free | also accessible; the `nano` account is rejected here |
| `es0`, `es1`, `es2` | `ac_nanotheory` | paid | GPU resources (es0 RTX 2080 Ti; es1 A40, A100, V100, RTX 8000; es2 H100, H200) |
| other LRC partitions (`lr*`, `cf1`, `cm*`, ...) | - | paid or unverified | |

- Submitting to a paid or unverified partition needs explicit user confirmation first.
- QOS: `normal` for every free partition. List your associations with `sacctmgr -nP show assoc user=$USER format=account,partition,qos`.

## Where can a job start

```bash
sinfo -s -p etna,etna_bigmem,etna_c40,etna_gpu        # NODES(A/I/O/T): allocated/idle/other(down, drain)/total
squeue -t PD -p etna,etna_bigmem,etna_c40 -h -o %P | sort | uniq -c   # pending jobs per partition
sinfo -p etna -R                                      # why nodes are drained or down
sinfo -p etna_gpu -N -t idle,mix -h -O NodeList:14,Gres:14,GresUsed:24   # usable GPU nodes and GPUs in use
squeue -u $USER                                       # your jobs
```

For a multi-node job that must wait for N free nodes of one partition, run [assets/node_window.sh](assets/node_window.sh) `-n N [-p PARTS] [-x EXCLUDE_FILE] -l LOG` instead of polling by hand: it counts only nodes in the exact `idle` state (`sinfo -t idle` also lists unusable `idle*` nodes), removes excluded nodes after expanding node lists, logs every reading and prints `WINDOW PART nodes` when a window opens.

etna is often fully allocated with many nodes drained or down. When it has no idle nodes, submit to `etna_bigmem` or `etna_c40` instead of queueing on `Priority`, and say so in the job name or notes since throughput differs.

## Job submission

- Standard CPU header: `--account=nano --partition=etna --qos=normal --exclusive --cpus-per-task=1`, ranks from the allocation (above), bounded `--time` sized from measured throughput, not step counts alone.
- Submit with `sbatch`. Never hold interactive `salloc` sessions for real work; they block the session and die with it.
- One job per configuration. Never loop rank counts or parameter points sequentially inside one allocation; submit independent jobs.
- Automate multi-step work inside one job (a chain script or an upstream runner) rather than resubmitting one step per job, which wastes queue time and races with the files each step writes.
- Never sleep-poll `squeue` in a loop. Use `mdwatch` if it is on your PATH (`lrc-mdwatch`); otherwise check back later.
- Exclude nodes that fail jobs while SLURM reports them healthy: keep the list in a file and submit with `sbatch -x "$(tr -s ',\n ' ',' < FILE | sed 's/^,*//; s/,*$//')" [options] script.sh`; `-x "$(<FILE)"` breaks on a file with one node per line.

## sbatch gotchas

- SLURM spools the batch script: `BASH_SOURCE[0]`-based `cd` lands in a spool directory. Use `cd "${SLURM_SUBMIT_DIR:-$(pwd)}"`.
- `/tmp` is node-local. `--output=/tmp/...` never appears on the login node; send output to the submit directory or scratch.
- OpenMPI reads slots from the allocation: `--ntasks=1 --cpus-per-task=24` gives `mpirun -np 4` "not enough slots". Allocate `--ntasks=N`, one per rank.
- `sbatch --export=VAR=x` REPLACES the environment (PATH, SLURM vars and HOME are stripped; multi-node orted daemons then fail). Use `--export=ALL,VAR=x`.
- Relative paths passed through `--export` resolve against `SLURM_SUBMIT_DIR` inside the job. Pass absolute paths.
- Module state does not persist between shells; load modules inside the script that uses them.
- On etna, `srun` does not bind tasks to cores (`--cpu-bind=cores` has no effect; every task gets the whole step mask). A multi-rank launch through `srun` lets OpenMPI pin all ranks to core 0, about 1000x slower. Launch MPI with `mpirun --map-by ppr:CORES:node --bind-to core` inside the allocation; for several independent MPI programs in one job, use one `mpirun` with LAMMPS `-partition` (see `comodino-campaigns`) rather than one `srun` per program.
- Users cannot ssh to compute nodes. To check a node in use (e.g. SMT), read `scontrol show node n0047.etna0` (`ThreadsPerCore=1` means SMT off); etna needs the full hostname.
- NEVER rename directories that running jobs use. File IO keeps working (inode-based), but OpenMPI re-resolves the cwd by path at the next `mpirun` and dies with "Open RTE was unable to initialize properly ... attempting to get the cwd. Returned value -11". Rename only after every job in the tree has ended.

## MPI binding is mandatory on etna

Unbound ranks are up to 14x slower (measured at 4 ranks; see `lrc-lammps` references); forcing shared-memory transports does not help. OpenMPI:

```bash
mpirun --bind-to core --map-by core -np N <exe> ...
```

Intel MPI: `I_MPI_PIN=1 I_MPI_PIN_DOMAIN=core`, verify the pin map once with `I_MPI_DEBUG=4`. Also set `OMP_NUM_THREADS=1` and `MKL_NUM_THREADS=1` unless the code is deliberately hybrid; library threading otherwise oversubscribes the node.

## References

- [assets/etna_cpu.sbatch](assets/etna_cpu.sbatch): free-partition CPU job with the header, submit-dir `cd`, thread pinning and bound `mpirun` on every allocated core. Replace the uppercase placeholders; pick the partition at submission (`sbatch -p etna_c40 ...`).
- [assets/partitions.sh](assets/partitions.sh): partition, account and cores per node for the free CPU partitions.
- [assets/node_window.sh](assets/node_window.sh): wait for N usable idle nodes of one partition.
- [references/software.md](references/software.md): Lmod module paths, Python environments, building software, GPU compatibility, Jupyter.
