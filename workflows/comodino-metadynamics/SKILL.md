---
name: comodino-metadynamics
description: Use when generating, authorizing, submitting, waiting for or recovering a CoMoDInO shared-walker metadynamics suite on Lawrencium (`comodino.md.sampling.metadynamics`, wall_ramp, wall_relax and metadynamics stages, walkers launched with LAMMPS -partition, a failed `STAGE.review.json`), including when a suite needs more free nodes than are idle. Walker starts and single bundles are in `comodino-chains`.
license: MIT
compatibility: Requires a Lawrencium (LBL LRC) account in the nano group and access to the private CoMoDInO package.
---

# Shared-walker metadynamics suites on Lawrencium

Follow these steps in order. Never write your own launcher, review script or stage loop. Background: CoMoDInO `docs/workflows/metadynamics_suite.md`, section "Current recipe".

1. **Protocol.** Suite protocol schema 2 with CV plan schema 3 in `sources/rNN_NN_metadynamics.json`. Every number (CVs, grids, `hill_width` in grid points, hill weight, deposition, walls, sharing interval, `restart_every_steps`, duration, walker count) comes from the user's recorded decision. The generator refuses a hill width outside 1-3, a wall within 6 sigma of a soft grid edge, and checkpoints not aligned with deposition and sharing.
2. **Generate** with `python -m comodino.md.sampling.metadynamics generate` into `rNN/NN_metadynamics` (absolute registry path; the folder must not exist yet).
3. **Per walker**, `comodino campaign policy rNN/NN_metadynamics/wNN` and `comodino campaign authorize rNN/NN_metadynamics/wNN --engine LMP --reference "..."`. Approve each policy on the user's decision or under an approval they delegated at campaign start. If walker sources ran on another rank count, the restart rank-count warning needs the user's decision.
4. **Check** with `python -m comodino.md.sampling.metadynamics run ... --stage wall_ramp --check-only` on the login node.
5. **Submit all stages as one job** from `99_jobs`, with [scripts/submit_suite.sh](scripts/submit_suite.sh) and [assets/suite_stage.sbatch](assets/suite_stage.sbatch) copied there:
   `bash submit_suite.sh SUITE wall_ramp,wall_relax,metadynamics [etna|etna_bigmem|etna_c40|dirac1]`
   It takes one node per walker at the partition's core count, runs the stages in order in that allocation with all walkers in one `mpirun`, reviews every walker after each stage, and stops at the first stage whose reviews do not all pass. A single stage (e.g. a rerun on another partition) is `submit_suite.sh SUITE STAGE`.
6. **Not enough free nodes** (`free_nodes.sh`, `lrc-nodes`): do not wait in the agent. Append the submit line to the queue of a detached `node_window.sh -q` (`lrc-nodes`) with `-n` the walker count and `-p` the partitions the user allowed:
   `echo 'cd CAMPAIGN/99_jobs && bash submit_suite.sh SUITE wall_ramp,wall_relax,metadynamics $WINDOW_PARTITION' >> QUEUE`
   One watcher serves all waiting suites in order.
7. **Wait** with a background `mdwatch wait JOBID --timeout 216000` (`lrc-mdwatch`): a 20 ns suite runs about 45-50 h on etna. On exit 1, report which stage failed (job output) and the `RECORDS/wNN/STAGE.review.json` decisions. Never resubmit a failed stage blindly.
8. **Recover.** A suite that ended normally needs no restart. If it failed, record the failure, confirm the job is gone, and recover from the latest checkpoint all walkers share with `python -m comodino.md.sampling.recovery generate` and `recovery run`, as one job like step 5. If recovery refuses, stop and ask the user.

When setting up several systems, create every system's suite and records before submitting any: a setup loop that dies part-way leaves later systems missing.
