#!/bin/bash
#SBATCH --job-name=chain
#SBATCH --account=nano
#SBATCH --partition=etna
#SBATCH --qos=normal
#SBATCH --exclusive
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --output=slurm-%x-%j.out

# One preparation or sampling bundle per job through comodino.md.execution.chain (runbook step 6).
# Submit with submit_chain.sh BUNDLE [START_STAGE] from CAMPAIGN/99_jobs: it names the job from the bundle path
# (e.g. 06i-brpt111-p01) and sets RECORDS, CODE and the mdwatch comment. Direct submission from CAMPAIGN/99_jobs
# with absolute paths also works; RECORDS=FAMILY/NN_system/rNN/records/NN_name
# holds authorization.json and continuation.json and receives the stage records. The job writes its launcher to
# RECORDS/launcher.JOBID.json with one rank per allocated core (24 on etna/dirac1, 32 on etna_bigmem, 40 on
# etna_c40), so every partition is used fully; a campaign launcher.json is not needed (LAUNCHER= overrides).
#   sbatch --comment=mdwatch:stall=30,watch=$BUNDLE --export=ALL,BUNDLE=...,RECORDS=...,START_STAGE=minimize,CODE=CAMPAIGN/99_jobs/comodino[,MODULE=...] comodino_chain.sbatch
# The job runs from 99_jobs but LAMMPS writes into BUNDLE, so mdwatch must watch BUNDLE to tell a hung stage
# from a working one; without watch= every chain looks idle after the stall window.
# Run the same comodino command with --check-only on the login node before submitting.

set -euo pipefail
BUNDLE=${BUNDLE:?} RECORDS=${RECORDS:?} START_STAGE=${START_STAGE:?} CODE=${CODE:?pin the campaign comodino worktree}
MODULE=${MODULE:-lammps/20250722u6-gcc}

export PATH="${ENV_BIN:-$HOME/miniforge3/envs/mdinterface/bin}:$PATH"
export PYTHONPATH="$CODE${PYTHONPATH:+:$PYTHONPATH}"
module load "$MODULE"
LMP=$(readlink -f "$LMP_EXEC")
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

ranks=$(( SLURM_CPUS_ON_NODE * SLURM_NNODES ))
if [[ -n "${LAUNCHER:-}" ]]; then
    launcher=$LAUNCHER
else
    mkdir -p "$RECORDS"
    launcher="$RECORDS/launcher.$SLURM_JOB_ID.json"
    printf '["mpirun", "--bind-to", "core", "--map-by", "core", "-np", "%s", "{engine}"]\n' "$ranks" > "$launcher"
fi
echo "launcher $(cat "$launcher") on $ranks allocated cores"
if [[ "$MODULE" == *intel* ]]; then
    export I_MPI_PIN=1 I_MPI_PIN_DOMAIN=core I_MPI_DEBUG=4
fi

echo "comodino $(python -c 'import comodino, pathlib; print(pathlib.Path(comodino.__file__).parent)') $(git -C "$CODE" rev-parse --short HEAD)"
echo "engine $MODULE $LMP $(sha256sum "$LMP" | cut -d' ' -f1)"

python -m comodino.md.execution.chain \
    --bundle "$BUNDLE" --reviews "$RECORDS" \
    --policy "$RECORDS/continuation.json" --authorization "$RECORDS/authorization.json" \
    --engine "$LMP" --launcher "$launcher" \
    --start-stage "$START_STAGE"
