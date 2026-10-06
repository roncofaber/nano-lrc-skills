---
name: lrc-lammps
description: Run LAMMPS molecular dynamics on the Lawrencium etna partitions with the nano group builds. Use when choosing a LAMMPS module or engine, writing LAMMPS inputs or launch lines, benchmarking ns/day or rank scaling, analyzing stage logs, or recording MD provenance. Use together with `lrc-cluster` for general sbatch and partition rules; for CoMoDInO campaigns use `comodino-campaigns`.
---

# LAMMPS MD on Lawrencium etna

Conventions for LAMMPS calculations on the etna partitions with the nano group builds. Cluster-wide submission and environment rules are in `lrc-cluster`.

## Engines

- CPU engines, both valid for production (update6, `-march=x86-64-v3`):
  - `lammps/20250722u6-intel25`: oneAPI 2025.2.1, Intel MPI, MKL FFT. About 6% faster than the GCC AVX2 build at 24 ranks; the old Intel NPT memory failure and iso box-symmetry bug are gone with this stack.
  - `lammps/20250722u6-gcc` (plain group install, OpenMPI) or `lammps/20250722u6-avx2` (GCC, full package set). The existing campaign manifests use `-gcc`.
- Keep one engine per campaign so runs stay comparable; the choice is recorded in the manifest.
- GPU engine: `lammps/20250722u6-gpu` (CUDA, sm_50/70/75/80/86).
- The module sets `LMP_ROOT` and `LMP_EXEC`; use `$LMP_EXEC` rather than guessing the path.
- The pre-update3 modules `lammps/20250722-gcc`, `-gpu` and `-intel` segfault (gcc, gpu) or are untested (intel) on `minimize` when `fix shake` uses `output_every=0`; the upstream bug was fixed in stable_22Jul2025_update3. The `comodino-campaigns` engine validation refuses them. Do not use any of them, nor anything under `lammps/old/` (note that `lammps/old/20241119-gpu` is the Lmod default, so always load an explicit version).
- `-intel25` and `-avx2` set `LMP_EXEC` through a symlink in the group software tree, so resolve with `readlink -f "$LMP_EXEC"` before hashing or recording the path.

## Launch

For a single run, start from `assets/etna_cpu.sbatch` in `lrc-cluster`. For a CoMoDInO bundle, see `comodino-campaigns`. OpenMPI builds (`-gcc`, `-avx2`):

```bash
module load lammps/20250722u6-gcc
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
mpirun --bind-to core --map-by core -np $(( SLURM_CPUS_ON_NODE * SLURM_NNODES )) "$LMP_EXEC" -in input -screen none
```

The `-intel25` build uses Intel MPI: pin through the environment instead (see "MPI binding" in `lrc-cluster`).

- Run on all cores of one node (24 on etna, 32 on etna_bigmem, 40 on etna_c40; see `lrc-cluster`). For systems of order 6000 atoms one node is the sweet spot (60% parallel efficiency at 24 ranks); 2 nodes are not worth it at that size. The 32- and 40-core nodes have not been benchmarked here yet: when a campaign first uses them, record ns/day at full node in its notes.
- Performance reference for ~6k atoms with PPPM + SHAKE: about 8 ns/day at 24 ranks on etna (see [references/performance.md](references/performance.md)); an ~8.5k-atom interface walker ran ~11 ns/day at 24 ranks on etna and dirac1, ~12.5 at 24 ranks on etna_bigmem.
- Size `--time` from measured throughput: a ~6k-atom chain of 5.52M steps at 0.5 fs runs in about 7.5 h at 204 steps/s on one 24-rank node, so 12 h fits with margin. Larger interface systems are slower; benchmark first. For multi-stage chains, support resume from the last completed stage's restart file (e.g. a `START_STAGE` variable checked against the stage list).

## Benchmarking

- One sbatch per rank count (never sequential runs inside one allocation).
- 10k-100k step runs; 1k steps is too noisy.
- Parse `Loop time` and `Performance:` lines from the LAMMPS log for ns/day.
- Save scripts, logs and a `BENCHMARK.md` summary in a numbered benchmark folder.

## LAMMPS input and log pitfalls

- LAMMPS restarts do NOT carry the kspace style. Generated stages restore electrostatics and groups after `read_restart`; any hand-written consumer must do the same before `run` or `minimize`.
- Define computes/variables before `thermo_style`. For group COM velocity use the native equal-style `vcm(group,dim)` function (there is no `compute vcm`). Minimization and dynamics stages print different thermo columns; parse the header, never assume fixed columns. Step counters reset per stage: never concatenate logs or trajectories across stages.
- In scripted sweeps use globs or `find`, never `$(ls ...)`: `ls` is often aliased to a colorized listing, and its escape codes become bogus path tokens.
- `"$LMP_EXEC" -help | head` gets SIGPIPE and, under `set -o pipefail`, aborts the job with exit 13. Write `-help` to a file first, then read the file.
- Aniso NPT with `fixedpoint 0 0 0` shows a stationary solid-minus-fluid temperature offset (about +15/-6 K) that vanishes in fixed-cell NVT stages; the uniform-background charge route prints the native PPPM net-charge warning. Both are expected.

## Provenance

- Builder manifests and pilot artifacts are hash-tracked (`build.json`, `manifest.json`): never modify hashed pilot files; put changes in a new versioned run directory and document what changed, why and how it was checked.
- Record the engine version, module, executable path and executable sha256 with every check or production run.
- Changing a campaign's engine mid-stream needs executable validation (for CoMoDInO, its preflight) and a new run directory; never rewrite historical hashed manifests to point at another build.
