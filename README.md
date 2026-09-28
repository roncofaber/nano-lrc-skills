# nano-lrc-skills

Agent skills for nano group members on the LBL Lawrencium cluster (LRC). They work in Claude Code, Codex, Gemini CLI and opencode.

## Install

```bash
/global/home/groups/nano/share/agent-skills/install.sh
```

This links every skill into `~/.claude/skills` and `~/.agents/skills`. It never touches your own skills: a name that already exists and does not come from this checkout is skipped with a warning. The shared checkout is updated every few hours, so edits reach you automatically. Rerun `install.sh` when new skills appear (`install.sh --check` lists them).

## Skills

| Skill | Use |
|---|---|
| `lrc-cluster` | SLURM, partitions, accounts, MPI binding, modules, software builds on LRC |
| `lrc-lammps` | LAMMPS engines, launch lines, benchmarking |
| `lrc-mdwatch` | job events, stall detection and failure diagnosis with mdwatch (optional) |
| `comodino-campaigns` | CoMoDInO campaign workflow on LRC |

`skills/` holds one skill per piece of software, `workflows/` one per multi-step scientific workflow. See [CONTRIBUTING.md](CONTRIBUTING.md) to add one.
