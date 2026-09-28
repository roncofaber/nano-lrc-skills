# CPU scaling of the NaCl pilot system on etna

Reference measurements. System: 2024 modified TIP3P-Ewald waters plus 1 NaCl pair, 6074 atoms, PPPM (lj/cut/coul/long 11.0/12.0), SHAKE, NPT 298 K / 1 atm, 0.5 fs timestep. Engine: `lammps/20250722u6-gcc` equivalent build (22 Jul 2025 series), GCC 13.2.0, MKL FFT.

## Method

- One independent sbatch per rank count (`--account=nano --partition=etna --exclusive`, `--ntasks=N --cpus-per-task=1`), excluded-node list applied.
- `mpirun --bind-to core --map-by core`, `OMP_NUM_THREADS=1`, `MKL_NUM_THREADS=1`.
- 10k-step NPT runs; input identical to the pilot physics minus colvars, dump, restart and minimize so the MD core cost is isolated.

## Results (10k steps)

| ranks | loop (s) | steps/s | speedup | efficiency |
|-------|----------|---------|---------|------------|
| 1     | 704.7    | 14.2    | 1.00x   | 100%       |
| 2     | 424.4    | 23.6    | 1.66x   | 83%        |
| 4     | 240.1    | 41.7    | 2.94x   | 73%        |
| 8     | 126.7    | 78.9    | 5.56x   | 70%        |
| 12    | 90.0     | 111.1   | 7.83x   | 65%        |
| 16    | 68.9     | 145.2   | 10.23x  | 64%        |
| 24    | 48.9     | 204.5   | 14.41x  | 60%        |
| 48 (2 nodes) | 40.4 | 247.6 | 17.45x | 36%        |

Equivalent rates at 24 ranks: about 204 steps/s, about 8.4 ns/day for 0.5 fs steps.

Chain measurements (heat stage, 24 ranks): 7.2 to 8.4 ns/day across the 1/4/10/20/40-pair systems; effectively uniform (atom counts differ by about 1%).

## Binding effect (why `--bind-to core` is mandatory)

- Unbound: 4 ranks took 338 s for the same 10k steps; bound: 23.5 s (14x).
- Slowdown is uniform across ranks in Kspace/Comm/Modify; local Pair compute is unaffected; node hardware was identical in both cases.
- Forcing shared-memory transports (`UCX_TLS=sm,self`, `--mca btl self,vader`) does not recover performance; binding does.
- `MKL_NUM_THREADS=1` alone does not fix it (MKL oversubscription was ruled out).

## Multinode

48 ranks on 2 nodes: 17.5x speedup but only 36% efficiency. Not worth it for systems of order 6000 atoms; scale within one 24-core node instead.

## Threading (OpenMP and MKL)

Same system, one sbatch per configuration, `--bind-to core`, OMP_PLACES=cores.

OpenMP hybrid always loses to pure MPI at this system size (steps/s):

| ranks x threads per rank | 1 node | 2 nodes | 4 nodes |
|--------------------------|--------|---------|---------|
| 24/node x 1 (pure MPI)   | 198    | 300     | 443     |
| 12/node x 2              | 107    | 191     | 313     |
| 6/node x 4               | 57     | 111     | 196     |
| 2-3/node x 8-12          | 24     | 55      | 114     |
| 1 rank x 24              | 14     | -       | -       |

Pure MPI scaling across nodes: 8.56 ns/day (1 node) -> 12.94 (2 nodes, 1.51x) -> 19.16 (4 nodes, 2.2x, about 44% efficiency). Beyond 2 nodes the return is poor for order-6000-atom systems.

MKL threading (FFT): no measurable effect at 1-2 nodes (MKL_NUM_THREADS 1 vs 2 vs dynamic all within noise), but with 96 ranks the dynamic default is 15% slower (MKL spawns threads per rank and oversubscribes). Keep `MKL_NUM_THREADS=1` and `OMP_NUM_THREADS=1` everywhere; do not use OpenMP hybrid layouts for small systems.
