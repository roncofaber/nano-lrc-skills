#!/bin/bash
#SBATCH --job-name=validate
#SBATCH --account=nano
#SBATCH --partition=etna
#SBATCH --qos=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:30:00
#SBATCH --output=slurm-%x-%j.out

# Validate one LAMMPS module for a CoMoDInO campaign (runbook step 5). Submit from CAMPAIGN/99_jobs:
#   sbatch --export=ALL,CAMPAIGN=/abs/campaign,MODULE=lammps/20250722u6-gcc,CODE=/abs/comodino-checkout[,PILOT=/abs/structure] engine_validation.sbatch
# Writes CAMPAIGN/00_validation/NN_<module>/ (next free NN); PILOT additionally runs the bulk smoke check,
# whose outputs land in PILOT/checks/<label> as prepare_pilot.py decides.

set -euo pipefail
CAMPAIGN=${CAMPAIGN:?} MODULE=${MODULE:?} CODE=${CODE:?}

case "$MODULE" in
    lammps/20250722-gcc|lammps/20250722-gpu|lammps/20250722-intel|lammps/old/*)
        echo "Refusing $MODULE: pre-update3 22Jul2025 builds crash on minimize with fix shake output_every=0." >&2
        exit 2 ;;
esac

export PATH="${ENV_BIN:-$HOME/miniforge3/envs/mdinterface/bin}:$PATH"
export PYTHONPATH="$CODE${PYTHONPATH:+:$PYTHONPATH}"
module load "$MODULE"
LMP=$(readlink -f "${LMP_EXEC:?module did not set LMP_EXEC}")
export OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

n=$(find "$CAMPAIGN/00_validation" -mindepth 1 -maxdepth 1 -type d -name '[0-9][0-9]_*' ! -name '*.failed.*' | wc -l)
label="$(printf '%02d' $((n + 1)))_$(tr '/.-' '___' <<< "$MODULE")"
out="$CAMPAIGN/00_validation/$label"
mkdir "$out"
trap '[[ -f "$out/VALIDATED" ]] || mv "$out" "$out.failed.$SLURM_JOB_ID"' EXIT
COMODINO_EXECUTION_REFERENCE="slurm:$SLURM_JOB_ID module:$MODULE node:$(hostname)"
export COMODINO_EXECUTION_REFERENCE

{
    echo "module $MODULE"
    echo "executable $LMP"
    echo "sha256 $(sha256sum "$LMP" | cut -d' ' -f1)"
    echo "comodino $(git -C "$CODE" rev-parse HEAD) $(git -C "$CODE" status --porcelain | wc -l) dirty files"
    echo "reference $COMODINO_EXECUTION_REFERENCE"
} | tee "$out/engine.txt"
"$LMP" -h > "$out/lmp_help.txt" 2>&1 || true
python -m pip freeze > "$out/pip_freeze.txt"

cd "$CODE"
COMODINO_TEST_LAMMPS="$LMP" COMODINO_TEST_COLVARS_LAMMPS="$LMP" \
    python -m pytest -q -rs --basetemp="$out/pytest" \
    tests/test_md_recipe.py tests/test_interface_recipe.py tests/test_interface_dynamics.py \
    tests/test_md_metadynamics_native.py tests/test_md_sampling.py::test_native_observation_restart \
    2>&1 | tee "$out/pytest_report.txt"
if grep -qE '[0-9]+ skipped' "$out/pytest_report.txt"; then
    echo "FAIL: native tests were skipped; every listed test must run" | tee -a "$out/pytest_report.txt"
    exit 1
fi

if [[ -n "${PILOT:-}" ]]; then
    python "$CODE/examples/md_workflow/prepare_pilot.py" check --pilot "$PILOT" --engine "$LMP" --label "$label" --smoke \
        2>&1 | tee "$out/smoke_check.txt"
fi
touch "$out/VALIDATED"
echo "VALIDATION COMPLETE $out"
