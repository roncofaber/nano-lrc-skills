# nano-lrc-skills

[Agent skills](https://agentskills.io) and scripts for running calculations on the LBL Lawrencium cluster (LRC) as a member of the nano group: SLURM partitions and accounts, MPI binding, node health, LAMMPS, job watching, and CoMoDInO molecular dynamics campaigns. They work in any agent that reads `~/.claude/skills` or `~/.agents/skills` (Claude Code, Codex, Gemini CLI, opencode, ...), and every script also runs by hand.

The skills encode site facts (partition names, core counts, the nano module tree, measured performance), so outside Lawrencium they are mostly useful as an example of how to write cluster skills for your own site.

## Install

On Lawrencium, nano members use the shared checkout and need no clone:

```bash
/global/home/groups/nano/share/agent-skills/install.sh
/global/home/groups/nano/share/agent-skills/install.sh --personal   # optional, see below
```

Anywhere else:

```bash
git clone https://github.com/roncofaber/nano-lrc-skills.git && nano-lrc-skills/install.sh
```

`install.sh` symlinks every skill into `~/.claude/skills` and `~/.agents/skills`, so `git pull` updates them in place. It never touches skills that are not its own: an existing name that does not point into the checkout is skipped with a warning. Rerun it when skills are added, moved or removed; `--check` lists what would change and `--uninstall` removes its links.

Nodes that fail jobs or run slow while SLURM reports them healthy go in the group's shared list, `/global/home/groups/nano/share/excluded_nodes` (one node per line, `# who, when, why`), so one member's finding keeps everyone's jobs off that node. Every script that submits or picks nodes skips them; `EXCLUDE_NODES_FILE=FILE` uses another list instead and `EXCLUDE_NODES_FILE=` none.

### Your own conventions

The shared skills stay generic. `install.sh --personal` creates `~/.agents/skills/$USER-lrc/SKILL.md` from [templates/personal-lrc](templates/personal-lrc/SKILL.md), linked for Claude Code too, with slots for your paths, checkouts, Python env, folder layout and what agents may do without asking. Fill in its TODO lines; it is never overwritten.

## Skills

| Skill | Use |
|---|---|
| `lrc-cluster` | partitions, accounts, sbatch, MPI binding, modules, building software |
| `lrc-nodes` | where a job can start, waiting for N free nodes, slow and excluded nodes |
| `lrc-lammps` | LAMMPS modules, launch lines, benchmarking, provenance |
| `lrc-mdwatch` | waiting for jobs, job events, stall detection, failure diagnosis with [mdwatch](https://github.com/roncofaber/mdwatch) |
| `comodino-campaigns` | CoMoDInO campaign setup, decisions, engine validation, analysis |
| `comodino-chains` | checking, submitting and resuming CoMoDInO bundles and walker starts |
| `comodino-metadynamics` | CoMoDInO shared-walker metadynamics suites |

The `comodino-*` skills drive [CoMoDInO](https://github.com/roncofaber/comodino), which is not public yet.

## Scripts

Each skill keeps its scripts in `scripts/` and its job templates in `assets/`. Every script runs with `bash`, prints its usage with `-h`, exits 2 on bad arguments, writes results to stdout and progress to stderr, and skips the excluded nodes wherever it submits or picks nodes.

| Script | Does |
|---|---|
| `lrc-cluster/scripts/partitions.sh` | account and cores per node of the free CPU partitions |
| `lrc-cluster/scripts/xbatch.sh` | `sbatch` that skips the excluded nodes |
| `lrc-cluster/scripts/excluded_nodes.sh` | the excluded nodes in effect, comma-separated |
| `lrc-nodes/scripts/free_nodes.sh` | usable idle nodes, pending jobs and free GPUs per partition |
| `lrc-nodes/scripts/node_window.sh` | waits for N idle nodes of one partition, then runs queued submissions |
| `lrc-nodes/scripts/node_bench.sh` | A/B benchmark of a suspect node, report of degraded nodes |
| `lrc-lammps/scripts/engine_info.sh` | module, resolved executable and sha256 of a LAMMPS build |
| `lrc-lammps/scripts/lammps_perf.sh` | ranks, steps/s and ns/day from LAMMPS logs |
| `lrc-mdwatch/scripts/watchers.sh` | running waits and watchers, last job events, watcher log tails |
| `comodino-chains/scripts/submit_chain.sh` | submits one CoMoDInO bundle as one chain job |
| `comodino-metadynamics/scripts/submit_suite.sh` | submits the stages of a shared-walker suite as one job |

## Checks

| Check | Where | What |
|---|---|---|
| `tests/run.sh`, `check.sh` | CI, every push | script behaviour; skill format ([skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref)), word budget, script conventions, links |
| `evals/triggers.sh` | by hand, after changing a description | each request in `evals/triggers.tsv` routes to the expected skill; one cheap model call per case (`EVAL_CMD`, default `claude -p`) |
| `tests/site.sh` | on Lawrencium, monthly | partition cores and accounts, GPU nodes, LAMMPS modules, group paths and reference-rate age still match the skills |

## Maintaining the shared checkout

`/global/home/groups/nano/share/agent-skills` is a clone owned by its maintainer and refreshed by the maintainer's dotfiles timer, which runs `git pull --ff-only && chmod -R g+rX .` in it every few hours and `tests/site.sh` once a month (the log goes to `~/.local/state/dotfiles/site-check.log`). To take it over, clone into the same path from your account and schedule both.

`skills/` holds one skill per piece of software or cluster topic, `workflows/` one per multi-step scientific workflow. See [CONTRIBUTING.md](CONTRIBUTING.md) to add one.

## License

[MIT](LICENSE)
