# CoMoDInO on Lawrencium: site map for the campaign runbook

CoMoDInO's `docs/workflows/campaign_runbook.md` (in your checkout, or exported with `comodino resources NEW_DIR`) is the procedure. This file only says what each step needs on Lawrencium.

| Runbook step | Lawrencium specifics |
|---|---|
| Campaign layout | `comodino campaign init` under your scratch project folder (`/global/scratch/users/$USER/...`). |
| 0. Environment | Use a Python 3.12 env with editable comodino and mdinterface (`main`); PACKMOL is in the env `bin/`. Pin the campaign's comodino commit as a worktree in `99_jobs/comodino` and pass it as `CODE=` to the job scripts. Record both commits in `decisions.md`; `engine_validation.sbatch` writes `pip freeze` to `00_validation/NN_<engine>/pip_freeze.txt`, which `decisions.md` cites. |
| 3-4. Build and generate | Login node is fine; generators run no MD. |
| 5. Validate the engine | Do this first, right after step 0. `assets/engine_validation.sbatch` from `99_jobs/`, once for the campaign's engine; writes `00_validation/NN_<module>/`. Required LAMMPS packages (KSPACE, MOLECULE, RIGID, COLVARS) are all in `lammps/20250722u6-gcc`. |
| 6. Authorize and run | Records, `authorization.json`, `continuation.json` in `FAMILY/NN_system/rNN/records/NN_name/`. One `99_jobs/launcher.json` per campaign. `assets/comodino_chain.sbatch` from `99_jobs/`, one job per bundle, `--check-only` first on the login node with absolute paths. Engine sha256 in `authorization.json` must be of `readlink -f "$LMP_EXEC"`. |
| 7-9. Accept, sample, assess | Anything that reads trajectories (`comodino campaign analysis`, `comodino.md.analysis.cv_proposal`, RDFs, coordination numbers) runs as a short etna sbatch job from `99_jobs/`, never on the login node: it saturates the shared node and hangs every other session there. The login node only reads the resulting `report.json` and CSV files. Sampling bundles run through the same chain template. |

## Adapter notes

- Isolated charged ions use `prepare_pilot.py build-reference`; chloride at an interface uses `examples/md_workflow/interface_cl_au111.json` (review ships pending).
- Interface PPPM accuracy comes from the structure manifest, not the dynamics protocol.

## Building with mdinterface

mdinterface (GitHub `main`, editable in your env) builds the structure; API usage is in its `docs/quickstart.md` and `docs/guide/simcell.md`. The `structure.json` metadata export that CoMoDInO requires is only on `main`, not in released 1.5.4.

- Export with `write_lammps(..., atom_style="full", metadata="structure.json")`. The sidecar records final atom/type/molecule IDs, groups, connectivity and the data-file sha256; CoMoDInO verifies it and refuses mismatched bundles. `build.json` records `structure_metadata="unavailable_legacy_mdinterface"` when the env's mdinterface is too old to write it, so refresh the editable install before building.
- Data and coefficients are LAMMPS `real` units; consuming inputs must use `units real`.
- mdinterface does not check charge neutrality. The bulk builder rejects non-neutral compositions, and `comodino.md.inputs.surface` requires an explicit compensation choice (`explicit_counterion` or `uniform_background`). Check summed charges yourself for any hand-built system.
- The initial box must exceed twice the largest cutoff.
- Builds are not reproducible: PACKMOL gets a fresh random seed each build. Never rebuild to reproduce a pilot; reuse its hashed artifacts.
- When PACKMOL fails for concentrated systems, use `dilate` (pack into a taller box at lower density; NPT compresses it) or lower `packmol_tolerance` (default 2.0 A). Failures raise `PackmolError` and keep a `packmol_*` temp dir (input, log, per-species PDBs) named in the error.
- Ion parameters come from the mdinterface database at its stored precision (the `Cheatham` entry is rounded to 5 significant figures). `parameter_locks` are verified with atol 1e-6 and a mismatch is a hard failure: `build.json` gets `status: "failed"`, even though the console only prints an ACTUAL/DESIRED table that reads like a warning. Set locks to the database values, or extend mdinterface for full precision.
- Water models: read the `mdinterface/database/molecules.py` docstrings, not `docs/guide/database.md`, whose variable names are swapped. `model="ewald"` is the pilots' modified TIP3P-Ewald water (q_O=-0.83).

## Gates agents must not skip (details in the runbook)

- Every `--output` (and `comodino.md.inputs.surface --manifest` source) must be a new directory; the source JSON lives outside it. Generators refuse existing outputs, but direct LAMMPS runs overwrite stage artifacts, so check before launching.
- Interface protocols: copy `examples/md_workflow/interface_dynamics.json` to a study-specific file outside the output tree, set both seeds, durations and cadences, and record an actual review before changing `review.status` from `pending` to `approved`. Never fabricate approval; the geometry review does not approve dynamics.
- Resolve unspecified force fields, probes, donor sites, CVs and bias intent with the user. Never silently select the first ion.
- Use exported `structure.json` metadata for type IDs, groups and water connectivity; never guess type numbers.
