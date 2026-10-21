# Agent instructions

This repo holds agent skills for the nano group on Lawrencium. Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing a skill; its rules are enforced by `check.sh`.

## Before saying a change is done

```bash
bash tests/run.sh && ./check.sh
```

Both must pass. After changing any skill `description`, also run `evals/triggers.sh` (one model call per case) and add cases to `evals/triggers.tsv` for a new skill.

## Rules that are easy to miss

- Never edit `/global/home/groups/nano/share/agent-skills`; it is the shared deployment and only updates from `main` by fast-forward. Work in a clone and open a PR.
- A new or changed script must be listed in its skill's `SKILL.md`, in the README script table, and tested in `tests/run.sh` (fake `sbatch`, `sinfo`, `squeue` on PATH).
- A new cluster fact stated in a skill gets a check in `tests/site.sh`.
- No personal paths, accounts other than `nano`, or credentials in skills. Personal conventions go in the user's own `$USER-lrc` skill, not here.
- Keep each `SKILL.md` body at most 700 words; move detail to `references/` or split the skill by task.
- When adding, renaming or removing a skill, update the README skill table and tell the user that everyone must rerun `install.sh`.
