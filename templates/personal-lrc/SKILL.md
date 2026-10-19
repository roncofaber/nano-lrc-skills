---
name: USERNAME-lrc
description: Use whenever working on Lawrencium (LRC) in the USERNAME account, together with `lrc-cluster`, `lrc-nodes`, `lrc-lammps`, `lrc-mdwatch` or the `comodino-*` skills - it gives the real paths, checkouts, Python env, folder layout, excluded nodes and agent autonomy rules those shared skills leave generic.
---

# Personal Lawrencium conventions (USERNAME)

Created from the nano-lrc-skills template: replace every TODO with your own value, or delete the line. Keep it short; shared facts belong in the shared skills.

## Paths

- Scratch: `/global/scratch/users/USERNAME` (TODO: any shortcut link, e.g. `~/scratch`).
- Checkouts: TODO, e.g. comodino at `~/src/comodino` (`CHECKOUT` in `comodino-campaigns`).
- Python env: TODO, e.g. `~/miniforge3/envs/md` (`ENV` in `comodino-campaigns`).
- Excluded nodes: the nano group list (`lrc-nodes`); TODO only if you keep your own, `export EXCLUDE_NODES_FILE=...` in `~/.bashrc`.

## Folder layout

- TODO: how projects are organised, e.g. `~/scratch/<NN_project>/<NN_campaign>/`, every level zero-padded in creation order, never reusing a prefix.
- Record conventions and findings in the project `AGENTS.md` as they appear.

## Agent autonomy

- TODO: what agents may do without asking, e.g. "submit, wait for and cancel my own jobs on the free nano partitions; paid partitions always need my confirmation".

## From a workstation (optional)

- TODO: SSH alias for `lrc-login.lbl.gov`, scratch mounts, how to reuse a multiplexed connection instead of a new OTP login.
