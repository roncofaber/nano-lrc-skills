---
name: comodino-campaigns
description: Use when starting, setting up, validating, analysing or handing off a CoMoDInO molecular dynamics campaign on Lawrencium (`comodino campaign init`, `campaign check` failing, `decisions.md`, engine validation, RDF or CV analysis jobs), or when unsure which CoMoDInO step comes next. Running bundles is in `comodino-chains`, shared-walker metadynamics in `comodino-metadynamics`; LAMMPS engines in `lrc-lammps`, sbatch and partitions in `lrc-cluster`.
license: MIT
compatibility: Requires a Lawrencium (LBL LRC) account in the nano group and access to the private CoMoDInO package.
---

# CoMoDInO campaigns on Lawrencium

CoMoDInO ([github.com/roncofaber/comodino](https://github.com/roncofaber/comodino), private: ask the maintainer for access) owns the recipes, generators, chain runner and campaign layout. Its `docs/workflows/campaign_runbook.md` is the ordered procedure from decisions to analysis, with commands and gates: follow it and do not re-derive the pipeline. Its `skills/comodino/SKILL.md` covers the science. These skills add only the Lawrencium side; [references/comodino.md](references/comodino.md) maps each runbook step to it.

`CHECKOUT` is your comodino clone and `ENV` a Python 3.12 env with editable comodino and mdinterface installs (e.g. `$HOME/miniforge3/envs/mdinterface`). Job scripts take the env's `bin/` from `ENV_BIN`; conda envs have no `bin/activate`, so never source it.

## Intake and decisions

- Before creating anything, run the runbook's "Campaign intake": ask its questions, show its Defaults and the site defaults below for confirmation, and offer only the systems it lists as supported. Also ask for the allocation (default `nano` on etna) and the campaign location under scratch.
- Site defaults: engine `lammps/20250722u6-gcc`, recorded once in `decisions.md` and used everywhere (do not validate or switch builds unless asked); LJ mixing Lorentz-Berthelot (`md.mixing: "arithmetic"`) unless the user's force field requires `geometric` or `sixthpower`. Every other scientific setting comes from the runbook "Defaults", which `comodino campaign init` pre-fills.
- Coordination-CV cutoffs and exponents are never defaults: each system's production RDF gives them (runbook step 8), the user reviews them, and `comodino campaign observe` applies them.
- Decide only from the pinned CoMoDInO and mdinterface docs and code, these skills and what the user states. Other campaign folders, other agents' work and old handoffs are not reviewed defaults. Anything still open is a question for the user, never an agent choice.
- Record the user's starting instructions verbatim and dated in `decisions.md`; everything else stays `pending` until the user reviews it.

## Layout and tools

- `comodino campaign init CAMPAIGN` creates the campaign; `comodino campaign check CAMPAIGN` must pass before every handoff. Only `AGENTS.md`, `decisions.md` and numbered folders may sit at the root: notes, findings and logs go in `AGENTS.md` sections. Older campaigns keep their layout; never move active runs.
- Scheduler scripts and `slurm-*.out` logs live in `CAMPAIGN/99_jobs/`; submit from there. Copy the submit scripts and job templates of `comodino-chains` and `comodino-metadynamics` (`scripts/*.sh`, `assets/*.sbatch`) into it unchanged.
- Write each system's sources with `comodino campaign system CAMPAIGN/FAMILY/NN_name`, never by copying example files.
- The `comodino` command has `resources`, `skill` and `campaign ACTION` (init, check, system, seeds, policy, authorize, accept, analysis, observe); everything else is `python -m comodino...`.
- Use absolute paths in every runner and generator command: the runbook's relative examples assume the campaign root as working directory.
- Redo an acceptance, policy or authorization with `--supersede` (the old file becomes `NAME.superseded.N.json`). Never delete or rewrite records, stage results, reviews or launch records.

## Code pinning

- The runner imports `comodino` at every stage, so pulling `CHECKOUT` under a running chain breaks it. Pin the campaign with `git -C CHECKOUT worktree add CAMPAIGN/99_jobs/comodino COMMIT`; the job scripts put this `CODE` first on `PYTHONPATH`. Record the CoMoDInO and mdinterface commits in `decisions.md`.
- After pulling CoMoDInO, refresh the editable install (`ENV/bin/pip install --no-deps -e CHECKOUT`), or the `comodino` console script fails on its old entry point.

## Engine validation

Validate first (runbook step 5, needs no structures), once per campaign, from `99_jobs`:

```bash
sbatch --export=ALL,CAMPAIGN=/abs/campaign,MODULE=lammps/20250722u6-gcc,CODE=/abs/checkout engine_validation.sbatch
```

[assets/engine_validation.sbatch](assets/engine_validation.sbatch) refuses the broken pre-update3 modules, records module, executable sha256, comodino commit, `lmp -h` and `pip freeze` in `00_validation/NN_<engine>/`, and fails if any native test was skipped. The tests take about a minute.

## Analysis

Run anything that reads trajectories (`comodino campaign analysis`, `python -m comodino.md.analysis.cv_proposal`, RDFs) as a short etna sbatch job from `99_jobs`, never on the login node or in the agent's shell: it saturates the shared node and hangs every session on it. Then read `report.json` and the CSV files rather than `.png` or `.pdf` plots.

## Phasing

Give each phase its own agent, handing off through `AGENTS.md`: setup (init, sources, validation, builds, bundles, policies, submission), then acceptance after the chains finish (runbook step 7), then observation (step 8). One agent driving a whole campaign runs out of context and stops without reporting.
