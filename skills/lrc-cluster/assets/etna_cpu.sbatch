#!/bin/bash
#SBATCH --job-name=NAME
#SBATCH --account=nano
#SBATCH --partition=etna
#SBATCH --qos=normal
#SBATCH --exclusive
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=slurm-%j.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

module load MODULE
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

# one rank per allocated core: 24 on etna/dirac1, 32 on etna_bigmem, 40 on etna_c40
ranks=$(( SLURM_CPUS_ON_NODE * SLURM_NNODES ))
mpirun --bind-to core --map-by core -np "$ranks" EXE ARGS
