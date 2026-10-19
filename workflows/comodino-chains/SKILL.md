---
name: comodino-chains
description: Use when checking, submitting, resuming or recovering a CoMoDInO preparation, sampling, observation or walker-start bundle on Lawrencium - continuation policies, authorizations, `--check-only` gates not reaching `ready_for_preparation_chain`, `comodino.md.execution.chain` jobs, `IDLE CORES` warnings, a TIMEOUT or killed chain, or a leftover `.chain.lock`. Campaign setup is in `comodino-campaigns`; shared-walker suites in `comodino-metadynamics`.
license: MIT
compatibility: Requires a Lawrencium (LBL LRC) account in the nano group and access to the private CoMoDInO package.
---

# CoMoDInO chains on Lawrencium

Each preparation or sampling bundle runs as one sbatch job through `python -m comodino.md.execution.chain`. Never resubmit one stage per job from the agent, and never write a bespoke chain loop or review script: extend the continuation policy instead.

## Before submitting

1. Records for bundle `FAMILY/NN_system/rNN/NN_name` live in `FAMILY/NN_system/rNN/records/NN_name/`: `authorization.json`, `continuation.json` and the stage records.
2. `comodino campaign policy BUNDLE` writes the pending default continuation policy. Show it to the user and approve it only on their decision. Minimization must accept both `energy tolerance` and `force tolerance`.
3. `comodino campaign authorize BUNDLE --engine LMP --reference "..."`, where `LMP` is `readlink -f "$LMP_EXEC"`. Never write an authorization by hand.
4. Run the chain command with `--check-only` on the login node, with absolute paths and a launcher of the intended form, e.g. `["mpirun", "--bind-to", "core", "--map-by", "core", "-np", "24", "{engine}"]`. It stops at the first failing gate and names the file and field; fix and rerun until it reports `ready_for_preparation_chain`.

## Submitting

With [scripts/submit_chain.sh](scripts/submit_chain.sh) and [assets/comodino_chain.sbatch](assets/comodino_chain.sbatch) copied into `CAMPAIGN/99_jobs`, from there (`-h` prints the usage):

```bash
bash submit_chain.sh BUNDLE [START_STAGE [PARTITION]] [sbatch options]
```

- Excluded nodes (`lrc-nodes`) are skipped. Pick a partition with idle nodes now (`lrc-nodes`). The job takes the whole node and writes its launcher (`RECORDS/launcher.JOBID.json`) from the allocation, so never write a fixed `-np`. If the runner prints `IDLE CORES`, ranks fell short of the allocation: fix that.
- The job gets a short name (e.g. `06i-brpt111-p01`), the pinned `CODE=99_jobs/comodino` and `--comment=mdwatch:stall=30,watch=BUNDLE`, so `lrc-mdwatch` watches where LAMMPS writes.
- A stage may continue on another partition; comodino records the rank-count change.
- A passed continuation review is not physical acceptance: a finished chain reports `physical_acceptance="inconclusive"` until the scientific review.

## Resume and recovery

- Resume by resubmitting with `START_STAGE` set to the first unstarted stage. A stage that was running when the job died cannot be resumed in place: it needs a supported recovery procedure or a regenerated bundle as a new numbered sibling (e.g. `03_prepare_dt05fs`).
- A killed job (TIMEOUT, NODE_FAIL, scancel) leaves `BUNDLE/.chain.lock`. Confirm the job is gone (`squeue`, or `mdwatch show JOBID`) before deleting it.
- Never hand-edit or `sed` generated inputs: any changed setting means a copied protocol JSON and a new bundle.

## Walker starts for interface metadynamics

- Generate distinct starts from the accepted interface preparation with `python -m comodino.md.sampling.branches generate` (CoMoDInO `docs/workflows/walker_starts.md`): branches in `rNN/NN_walker_starts/wNN`, records in `rNN/records/NN_walker_starts/wNN/`. The count, duration (default 200 ps) and start frames (`"frames": "spaced"` from the accepted production, or its final state) are the user's decision.
- Give each branch its own policy, authorization and `--check-only`, then its own single-node job, all running concurrently on whatever nodes are free: `bash submit_chain.sh rNN/NN_walker_starts/wNN nvt_sample [PARTITION]`.
- After the branches finish: interface analysis and `comodino campaign accept` per branch, then `branches spread` once for the set. The suite itself (`comodino-metadynamics`) needs a common start for all walkers, unlike the branches.
