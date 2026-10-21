# nano-lrc-skills

[Agent skills](https://agentskills.io) and scripts for running calculations on the LBL Lawrencium cluster (LRC) as a member of the nano group: SLURM partitions and accounts, MPI binding, node health, LAMMPS, job watching, and CoMoDInO molecular dynamics campaigns. They work in any agent that reads `~/.claude/skills` or `~/.agents/skills` (Claude Code, Codex, Gemini CLI, opencode, ...), and every script also runs by hand.

The skills encode site facts (partition names, core counts, the nano module tree, measured performance), so outside Lawrencium they are mostly an example of how to write cluster skills for your own site.

## Install

On Lawrencium, use the group's shared copy. No clone needed:

```bash
/global/home/groups/nano/share/agent-skills/install.sh
```

Anywhere else, clone and install:

```bash
git clone https://github.com/roncofaber/nano-lrc-skills.git && nano-lrc-skills/install.sh
```

`install.sh` symlinks each skill into `~/.claude/skills` and `~/.agents/skills`. It never touches skills that are not its own. `--check` shows what would change, `--uninstall` removes its links.

Optionally, `install.sh --personal` creates your own `$USER-lrc` skill from [a template](templates/personal-lrc/SKILL.md) for your paths, checkouts, Python env and what agents may do without asking. Fill in its TODO lines; it is never overwritten.

## Staying up to date

The shared copy follows `main` on GitHub and refreshes itself every few hours. Because skills are symlinks, changes to existing skills reach you automatically. When a skill is added, renamed or removed, rerun `install.sh` once.

## Changing the skills

Never edit the shared copy: it belongs to the maintainer and local edits block its updates. Instead:

1. Clone the repo into your own space (fork it first if you cannot push to it), and create a branch.
2. Make your change, following [CONTRIBUTING.md](CONTRIBUTING.md). Run `tests/run.sh` and `./check.sh`.
3. To try it in your agent before merging, point your links at your clone, then switch back when done:

   ```bash
   /global/home/groups/nano/share/agent-skills/install.sh --uninstall && ./install.sh     # use your clone
   ./install.sh --uninstall && /global/home/groups/nano/share/agent-skills/install.sh     # back to shared
   ```

4. Open a pull request. CI runs the same checks. Once merged, everyone gets it at the next refresh.

## Excluded nodes

Nodes that fail jobs or run slow while SLURM calls them healthy go in the group list, `/global/home/groups/nano/share/excluded_nodes` (one node per line, `# who, when, why`). Every script that submits or picks nodes skips them, so one member's finding protects everyone. Set `EXCLUDE_NODES_FILE=FILE` to use another list, or `EXCLUDE_NODES_FILE=` for none.

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

`skills/` holds one skill per piece of software or cluster topic, `workflows/` one per multi-step scientific workflow. The `comodino-*` skills drive [CoMoDInO](https://github.com/roncofaber/comodino), which is not public yet.

## Scripts

Each skill keeps its scripts in `scripts/` and job templates in `assets/`. Every script runs with `bash` and prints its usage with `-h`.

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

| Check | When | What |
|---|---|---|
| `tests/run.sh`, `./check.sh` | every push and PR (CI) | script behaviour, skill format, word budget, script conventions, links |
| `evals/triggers.sh` | by hand, after changing a description | each request in `evals/triggers.tsv` routes to the expected skill |
| `tests/site.sh` | monthly, on Lawrencium | the cluster facts in the skills still hold |

## Maintaining the shared copy

`/global/home/groups/nano/share/agent-skills` is a clone owned by its maintainer, whose scheduled job runs `git pull --ff-only && chmod -R g+rX .` in it every few hours and `tests/site.sh` monthly. To take it over, clone into the same path from your account and schedule both.

## License

[MIT](LICENSE)
