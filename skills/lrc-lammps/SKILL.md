---
name: lrc-lammps
description: Use when running LAMMPS on the Lawrencium etna partitions - choosing a nano group LAMMPS module, writing inputs or launch lines, benchmarking ns/day or rank scaling, sizing --time, reading LAMMPS logs, or recording MD provenance - or when `module load lammps` fails, `minimize` segfaults with fix shake, a restarted run lost its kspace style, or a job exits with code 13 after `lmp -help`. General sbatch rules are in `lrc-cluster`; CoMoDInO campaigns use `comodino-campaigns`.
license: MIT
compatibility: Requires a Lawrencium (LBL LRC) account in the nano group; SLURM, Lmod and bash.
---

# LAMMPS on Lawrencium etna

## Modules

| Module | Build |
|---|---|
| `lammps/20250722u6-gcc` | GCC, OpenMPI; the default, used by existing campaigns |
| `lammps/20250722u6-avx2` | GCC, OpenMPI, full package set |
| `lammps/20250722u6-intel25` | oneAPI 2025.2.1, Intel MPI, MKL FFT; about 6% faster at 24 ranks |
| `lammps/20250722u6-gpu` | CUDA sm_50/70/75/80/86 (not es2 H100/H200) |

- Always load an explicit version: a bare `module load lammps` finds no default and fails. Never use `lammps/old/*` or the pre-update3 `lammps/20250722-gcc`, `-gpu`, `-intel`, which crash in `minimize` when `fix shake` uses `output_every=0`.
- Keep one engine per campaign so runs stay comparable.
- The module sets `LMP_EXEC`; use it. `-intel25` and `-avx2` point it through a symlink, so record the resolved path: `bash scripts/engine_info.sh MODULE` prints the module, resolved executable and sha256, and refuses the broken builds.

## Launch

Start from `assets/etna_cpu.sbatch` in `lrc-cluster`. OpenMPI builds:

```bash
module load lammps/20250722u6-gcc
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
mpirun --bind-to core --map-by core -np $(( SLURM_CPUS_ON_NODE * SLURM_NNODES )) "$LMP_EXEC" -in input -screen none
```

`-intel25` uses Intel MPI: pin through the environment instead (`lrc-cluster`, "MPI binding").

## Sizing

- ~6k atoms with PPPM + SHAKE at 0.5 fs: about 8 ns/day (204 steps/s) on one 24-rank etna node, 60% parallel efficiency. A second node is not worth it at that size, and OpenMP hybrids always lose. An ~8.5k-atom interface ran ~11 ns/day on etna and dirac1, ~12.5 on etna_bigmem. Scaling tables: [references/performance.md](references/performance.md).
- The 32- and 40-core nodes are not benchmarked at full node yet: record ns/day the first time a campaign uses them.
- Size `--time` from measured steps/s (`lammps_perf.sh`): 5.52M steps at 204 steps/s is about 7.5 h, so ask for 12 h. Multi-stage scripts should resume from the last completed stage's restart (e.g. a `START_STAGE` variable).

## Benchmarking

One sbatch per rank count; 10k-100k steps (1k is noise). `bash scripts/lammps_perf.sh LOG...` prints ranks, steps, loop time, steps/s and ns/day per log. Keep scripts, logs and a `BENCHMARK.md` summary in a numbered folder.

## Pitfalls

- Restarts do not carry the kspace style: after `read_restart`, redefine electrostatics and groups before `run` or `minimize`.
- Define computes and variables before `thermo_style`. Group COM velocity is the equal-style `vcm(group,dim)` function; there is no `compute vcm`.
- Minimization and dynamics print different thermo columns: parse the header. Step counters reset per stage: never concatenate logs or trajectories across stages.
- In scripts use globs or `find`, never `$(ls ...)`: an aliased `ls` emits color codes that become bogus paths.
- `"$LMP_EXEC" -help | head` gets SIGPIPE and, under `set -o pipefail`, kills the job with exit 13. Write `-help` to a file first.

## Provenance

- Record the `engine_info.sh` line (module, resolved executable, sha256) with every check or production run.
- Never modify hash-tracked files (`build.json`, `manifest.json`) or rewrite historical manifests: put changes in a new versioned run directory, noting what changed, why and how it was checked. Switching engine mid-campaign needs revalidation and a new run directory.
