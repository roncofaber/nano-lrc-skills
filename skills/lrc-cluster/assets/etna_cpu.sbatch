#!/bin/bash
#SBATCH --job-name=NAME
#SBATCH --account=nano
#SBATCH --partition=etna
#SBATCH --qos=normal
#SBATCH --exclusive
#SBATCH --nodes=1
#SBATCH --ntasks=24
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --output=slurm-%j.out

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

module load MODULE
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

mpirun --bind-to core --map-by core -np "$SLURM_NTASKS" EXE ARGS
