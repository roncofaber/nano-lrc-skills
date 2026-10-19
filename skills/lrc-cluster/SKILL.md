---
name: lrc-cluster
description: Use when working on the LBL Lawrencium cluster (LRC, SLURM) as a nano group member - writing or submitting sbatch scripts, choosing a partition or account, binding MPI ranks, loading Lmod modules from the nano group tree, building software, or planning GPU runs - or when a job fails with "not enough slots", "Open RTE was unable to initialize properly ... get the cwd", a lost environment after `sbatch --export`, or MPI ranks running far slower than expected. For free, slow or excluded nodes use `lrc-nodes`; for LAMMPS `lrc-lammps`; for job events and failure diagnosis `lrc-mdwatch`.
license: MIT
compatibility: Requires a Lawrencium (LBL LRC) account in the nano group; SLURM, Lmod and bash.
---

# Lawrencium (LRC) for nano members

SLURM 25.05, Rocky 8, Lmod. Follow these conventions unless the user says otherwise. Node counts and health change: check them (`lrc-nodes`) before planning around them.

Scripts are in this skill's `scripts/` folder; run them with `bash`, and `-h` prints their usage.

| Script | Does |
|---|---|
| `partitions.sh [PARTITION]` | account and cores per node of the free CPU partitions |
| `xbatch.sh [sbatch options] SCRIPT` | `sbatch` plus `--exclude` of the excluded nodes |
| `excluded_nodes.sh` | the excluded nodes as one comma-separated list (`lrc-nodes`) |

## Partitions and accounts

| Partition | Account | Cores/node | Notes |
|---|---|---|---|
| `etna` | `nano` | 24 | free, preferred for CPU MD; 64 GB |
| `etna_bigmem` | `nano` | 32 | free; 95 GB |
| `etna_c40` | `nano` | 40 | free; 96 GB |
| `dirac1` | `dirac1` | 24 | free; the `nano` account is rejected here |
| `etna_gpu` | `nano` | 8 | free; 2x V100 16 GB (sm_70), `--gres=gpu:V100:N`, N <= 2 |
| `es0`, `es1`, `es2` | `ac_nanotheory` | | paid GPUs ([references/software.md](references/software.md)) |
| anything else (`lr*`, `cf1`, `cm*`, ...) | | | paid or unverified |

- Submitting to a paid or unverified partition needs explicit user confirmation first.
- QOS is `normal` on every free partition. Scripts read accounts and core counts from `partitions.sh`, never hard-coded.

## Submitting

- Start from [assets/etna_cpu.sbatch](assets/etna_cpu.sbatch) and pick the partition at submission (`sbatch -p etna_c40 ...`). It takes whole nodes and runs one bound rank per allocated core, `$(( SLURM_CPUS_ON_NODE * SLURM_NNODES ))`: never hard-code 24. Use fewer ranks only for a measured reason, and record it.
- Size `--time` from measured throughput, not step counts alone.
- Submit with `bash scripts/xbatch.sh` (`lrc-nodes` for the excluded-nodes list). Never hold `salloc` sessions for real work: they block the session and die with it.
- One job per configuration: independent rank counts or parameter points are separate jobs or a job array (`sbatch --array`), never a loop or a set of programs inside one allocation. Dependent steps of one calculation go in one job (a chain script).
- Never sleep-poll `squeue`. Use `mdwatch` if it is on PATH (`lrc-mdwatch`), otherwise check back later.
- Long-lived project data goes on `/global/scratch/users/$USER/`, not `$HOME`.
- Record conventions and findings in the project's `AGENTS.md` as they appear.

## MPI binding is mandatory

Unbound ranks run up to 14x slower on etna.

- OpenMPI: `mpirun --bind-to core --map-by core -np N EXE`; across nodes `--map-by ppr:CORES:node --bind-to core`.
- Intel MPI: `I_MPI_PIN=1 I_MPI_PIN_DOMAIN=core`; check the pin map once with `I_MPI_DEBUG=4`.
- `export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1` unless the code is deliberately hybrid.
- Never launch MPI ranks with `srun` on etna: it does not bind (`--cpu-bind=cores` is ignored), OpenMPI then pins every rank to core 0 and runs about 1000x slower. Coupled replicas (e.g. shared-bias metadynamics walkers) use one `mpirun` with LAMMPS `-partition` (`comodino-metadynamics`).

## sbatch gotchas

- SLURM spools the batch script: a `BASH_SOURCE[0]`-based `cd` lands in the spool directory. Use `cd "${SLURM_SUBMIT_DIR:-$(pwd)}"`.
- `/tmp` is node-local: `--output=/tmp/...` never reaches the login node.
- OpenMPI takes its slots from the allocation: `--ntasks=1 --cpus-per-task=24` makes `mpirun -np 4` fail with "not enough slots". Keep `--cpus-per-task=1` with `--exclusive` or `--ntasks=N`.
- `--export=VAR=x` replaces the whole environment (PATH, HOME and SLURM variables are lost; multi-node launches fail). Use `--export=ALL,VAR=x` with absolute paths.
- Module state does not carry into the job's shell: load modules in the script that uses them.
- Never rename a directory a running job uses: the next `mpirun` re-resolves the cwd by path and dies with "Open RTE was unable to initialize properly ... attempting to get the cwd. Returned value -11".

## Environment

- `crontab` and `scrontab` may be disabled: run recurring tasks as systemd user timers (`systemctl --user list-timers`), which survive logout only with linger (`loginctl show-user $USER -p Linger`).
- Group modules, Python environments, building software, GPU architectures and Jupyter: [references/software.md](references/software.md).
