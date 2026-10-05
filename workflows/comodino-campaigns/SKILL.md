---
name: comodino-campaigns
description: Set up and run CoMoDInO molecular dynamics campaigns on the Lawrencium etna partitions: campaign intake and layout, engine validation, bundle generation, continuation policies, comodino.md.execution.chain jobs, review gates, acceptance and observation. Use for any CoMoDInO campaign work on LRC, together with `lrc-lammps` (engines, launch lines) and `lrc-cluster` (sbatch and partitions).
---

# CoMoDInO campaigns on Lawrencium

CoMoDInO (github.com/roncofaber/comodino, private: ask the maintainer for access; package and imports `comodino`) owns the recipes, generators, chain runner and campaign layout, and ships no site material. Its `docs/workflows/campaign_runbook.md` is the single ordered procedure from decisions to analysis, with exact commands and gates; follow it and do not re-derive the pipeline here. Its `skills/comodino/SKILL.md` covers the science. This skill supplies only what the runbook leaves to the site: modules, environment, launcher, resources, scheduler scripts. [references/comodino.md](references/comodino.md) maps runbook steps to Lawrencium specifics.

Below, `CHECKOUT` is your comodino clone and `ENV` your Python env with editable comodino and mdinterface installs (for example `$HOME/miniforge3/envs/mdinterface`). The job scripts read the env's `bin/` from `ENV_BIN`; conda envs have no `bin/activate`, so never source it.

## Intake and defaults

- Before creating anything, run the runbook's "Campaign intake": ask its questions, show its Defaults and the site defaults below for confirmation, and offer only the systems it lists as supported. Site questions to add: allocation (default `nano` on etna) and campaign location under scratch.
- Decide only from the pinned CoMoDInO and mdinterface documentation and code, this skill, `lrc-cluster`, and what the user states when starting the campaign. Do not read other campaign folders, sibling agents' work or old handoffs to make decisions: they are not reviewed defaults. When the documentation is silent, ask the user or record an open question.
- Defaults, used unless the user specifies otherwise at campaign start:
  - Engine: `lammps/20250722u6-gcc`. Record it in `decisions.md` once and use that exact module everywhere in the campaign; do not validate or switch builds unless asked.
  - LJ mixing rule: Lorentz-Berthelot (`md.mixing: "arithmetic"`) unless the user names a force field that requires another rule (`geometric`, `sixthpower`).
  - Replicas, timestep, durations, interface geometry, numbering and every other scientific setting: the "Defaults" section of the runbook. `comodino campaign init` pre-fills them in `decisions.md`; cite that section as the review reference.
  - Coordination-CV cutoffs and exponents are never defaults: bulk preparations run without CVs, each system's own production RDF gives them (runbook step 8), the user reviews them, and `comodino campaign observe` applies them in a `02_observe` bundle.
  - Anything CoMoDInO leaves without a default is an open question for the user, never an agent choice.
- The user's instructions at campaign start approve the choices they name. Record them verbatim in `decisions.md` with the date; everything else stays `pending` until the user reviews it.

## Layout and tools

- Start with `comodino campaign init CAMPAIGN`; `comodino campaign check CAMPAIGN` must pass before every handoff. Only `AGENTS.md`, `decisions.md` and the numbered folders may sit at the campaign root: put notes, findings and logs in `AGENTS.md` sections, or `campaign check` fails. Older campaigns keep their own layout; never move active runs.
- Scheduler scripts, `launcher.json` and `slurm-*.out` logs live only in `CAMPAIGN/99_jobs/`; submit from there. Engine validation goes to `CAMPAIGN/00_validation/NN_<engine>/`.
- Write each system's sources with `comodino campaign system CAMPAIGN/FAMILY/NN_name`, never by copying example files.
- `comodino` has three installed subcommands: `resources`, `skill` and `campaign ACTION` (init, check, system, seeds, policy, accept, analysis, observe). Everything else is a `python -m comodino...` module; `python -m comodino.campaign` runs nothing.
- Use absolute paths in every runner and generator command: the runbook's relative examples assume the campaign root as working directory.

## Code pinning

- The runner imports `comodino` at every stage, so pulling `CHECKOUT` while chains run breaks them. Pin the campaign: `git -C CHECKOUT worktree add CAMPAIGN/99_jobs/comodino COMMIT`, and pass it as `CODE=`; the job scripts put it first on `PYTHONPATH`. Record the CoMoDInO and mdinterface commits in `decisions.md`.
- After pulling CoMoDInO, refresh the editable install (`ENV/bin/pip install --no-deps -e CHECKOUT`); otherwise the `comodino` console script keeps its old entry point and fails.

## Engine validation

Validate the engine first, before building anything (it needs no structures), once per campaign, with `sbatch` [assets/engine_validation.sbatch](assets/engine_validation.sbatch) (runbook step 5). It refuses the broken pre-update3 modules, records module, executable sha256, comodino commit, `lmp -h` and `pip freeze`, runs the native pytest checks under `00_validation/`, fails if any test skipped, and optionally runs the bulk smoke check. The native tests take about a minute; a short pass is expected as long as none skipped.

## Chains

- Run each preparation or sampling bundle as one sbatch through `python -m comodino.md.execution.chain`, never as an agent resubmitting one stage per job, and never with a bespoke chain loop or review script; extend the continuation policy instead.
- Write `CAMPAIGN/99_jobs/launcher.json` once per campaign: `["mpirun", "--bind-to", "core", "--map-by", "core", "-np", "24", "{engine}"]` for one etna node with the gcc build. The same file serves `--check-only` and the job, and the job refuses to start if its `-np` differs from `SLURM_NTASKS`.
- Records, `authorization.json` and `continuation.json` for bundle `FAMILY/NN_system/rNN/NN_name` live in `FAMILY/NN_system/rNN/records/NN_name/`.
- Continuation policies: `comodino campaign policy BUNDLE` writes the pending default into the records folder. Show it to the user and approve it only on their decision. Minimization must accept both `energy tolerance` and `force tolerance`.
- Before submitting, run the runner command with `--check-only` on the login node. It stops at the first failing gate and names the file and field; fix and rerun until it reports `ready_for_preparation_chain`.
- Submit with `bash` [assets/submit_chain.sh](assets/submit_chain.sh) `BUNDLE [START_STAGE]` from `99_jobs`. It runs [assets/comodino_chain.sbatch](assets/comodino_chain.sbatch) with a short job name (`<campaign NN><b|i>-<system>-<bundle>`, e.g. `06i-brpt111-p01`), RECORDS, CODE and `--comment=mdwatch:stall=30,watch=$BUNDLE`, so `lrc-mdwatch` watches the bundle where LAMMPS writes.
- A passed continuation review is not physical acceptance; chain completion reports `physical_acceptance="inconclusive"` until the separate scientific review.

## Resume and recovery

- Resume by resubmitting with `START_STAGE` set to the first unstarted stage. A stage that was running when the job died cannot be resumed in place: recovery needs a supported procedure or a regenerated bundle (a new numbered sibling, e.g. `03_prepare_dt05fs`).
- A killed job (TIMEOUT, NODE_FAIL, scancel) leaves `<bundle>/.chain.lock`. Confirm the job is gone (`squeue`, or `mdwatch show JOBID`) before deleting it.
- Never hand-edit or `sed` generated inputs. Any changed setting means a copied protocol JSON and a new bundle.

## Walker starts for interface metadynamics

- Prepare a suite's distinct walker starts with `python -m comodino.md.sampling.branches generate` from the accepted interface preparation (CoMoDInO `docs/workflows/walker_starts.md`); it writes `rNN/NN_walker_starts/wNN`, records in `rNN/records/NN_walker_starts/wNN/`. Count, duration (default 200 ps) and whether branches start from evenly spaced frames of the accepted production (`"frames": "spaced"`) or from its final state are the user's decision.
- Give each branch `comodino campaign policy`, an authorization and `--check-only`, then submit each as its own single-node job: `bash submit_chain.sh rNN/NN_walker_starts/wNN nvt_sample` (job name `<NN>i-<system>-wNN`). Run them concurrently on as many nodes as are free; they are independent until the suite.
- After the branches finish: interface analysis per branch, `comodino campaign accept` per branch, then `branches spread` once for the set. The suite itself needs a common start for all walkers, unlike the branches.

## Analysis

- Run trajectory analysis (`comodino campaign analysis`, `python -m comodino.md.analysis.cv_proposal`, RDFs) as a short etna sbatch job from `99_jobs`, never on the login node or in the agent's shell: it pins the shared node and hangs every other session on it. Read the resulting `report.json` and CSV files afterwards.
- With a text-only model, read `report.json` and CSV files instead of opening `.png` or `.pdf` plots.

## Agent phasing

Split long campaigns into phases, one agent each, handing off through the campaign `AGENTS.md`: setup (init, sources, engine validation, builds, bundles, policies, chain submission); after the chains finish, acceptance (step 7); then observation (step 8). One agent driving a whole campaign runs out of context and stops without reporting.
