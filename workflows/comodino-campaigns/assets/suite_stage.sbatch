#!/bin/bash
#SBATCH --job-name=suite
#SBATCH --account=nano
#SBATCH --partition=etna
#SBATCH --qos=normal
#SBATCH --exclusive
#SBATCH --nodes=12
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --time=60:00:00
#SBATCH --output=slurm-%x-%j.out

# One stage (wall_ramp, wall_relax or metadynamics) of a shared-walker suite: all walkers start together in one
# mpirun split by LAMMPS -partition, one walker per node, then every walker is reviewed. Submit with
# submit_suite.sh SUITE STAGE from CAMPAIGN/99_jobs; it sets the node count from the walker count and the account
# for the partition.

set -euo pipefail
SUITE=${SUITE:?} STAGE=${STAGE:?} CODE=${CODE:?pin the campaign comodino worktree}
MODULE=${MODULE:-lammps/20250722u6-gcc}

export PATH="${ENV_BIN:-$HOME/miniforge3/envs/mdinterface/bin}:$PATH"
export PYTHONPATH="$CODE${PYTHONPATH:+:$PYTHONPATH}"
module load "$MODULE"
LMP=$(readlink -f "$LMP_EXEC")
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

RECORDS="$(dirname "$SUITE")/records/$(basename "$SUITE")"
launcher="$RECORDS/launcher.$SLURM_JOB_ID.json"
printf '["mpirun", "--map-by", "ppr:%s:node", "--bind-to", "core", "-np", "%s", "{engine}"]\n' \
    "$SLURM_NTASKS_PER_NODE" "$SLURM_NTASKS" > "$launcher"

echo "comodino $(git -C "$CODE" rev-parse --short HEAD)  engine $MODULE $LMP $(sha256sum "$LMP" | cut -d' ' -f1)"
echo "suite $SUITE stage $STAGE  nodes $SLURM_JOB_NODELIST"
python -m comodino.md.sampling.metadynamics run --bundle "$SUITE" --stage "$STAGE" --reviews "$RECORDS" \
    --authorizations "$RECORDS/authorizations" --engine "$LMP" --launcher "$launcher"
