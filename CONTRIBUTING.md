# Contributing a skill

1. Branch, add `skills/lrc-<topic>/` (or `workflows/<workflow>/`) with a `SKILL.md`, open a pull request. CI runs `tests/run.sh` and `check.sh`; both must pass. Run them locally first. `check.sh` also runs the official spec validator, [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref), when it is on PATH; CI and `evals/triggers.sh` use it too. Install it from source at the commit CI pins, in its own environment (Python 3.11+):

   ```bash
   python3 -m venv ~/.local/share/skills-ref/venv
   ~/.local/share/skills-ref/venv/bin/pip install "skills-ref @ git+https://github.com/agentskills/agentskills.git@69ef37e9424c0a7ea9dd2293b559e43ec8176379#subdirectory=skills-ref"
   ln -s ~/.local/share/skills-ref/venv/bin/skills-ref ~/.local/bin/skills-ref
   ```

2. Frontmatter: `name` equal to the folder name, a one-line `description` of at most 1024 characters starting with "Use when", `license: MIT`, and a `compatibility` line. The description says when to load the skill: the tasks, commands and error messages an agent would see, not a summary of the body. Name the sibling skill to use for overlapping cases.
3. Add one or two requests per new skill to `evals/triggers.tsv`, and run `evals/triggers.sh` after changing any description.
4. Keep the `SKILL.md` body between 500 and 700 words; `check.sh` fails above 700. When a skill grows past that, split it by task (as the three `comodino-*` skills are split) or move detail that only some tasks need into `references/`.
5. Write rules and facts an agent acts on, not history: no stories of past incidents, bug archaeology or personal results. Keep one measured number where it sizes a decision. When a skill states a cluster fact, add it to `tests/site.sh`.
6. When an agent would otherwise compose a command or pipeline from prose, write a script instead. Scripts go in the skill's `scripts/`, job templates in `assets/`. A script:
   - starts with a comment block saying what it does, including a `# usage: NAME ...` line, which `-h` prints;
   - exits 2 on bad arguments, writes results to stdout and progress or errors to stderr;
   - skips the excluded nodes (`lrc-cluster/scripts/excluded_nodes.sh`) if it chooses or submits to nodes;
   - is listed in its skill's script table and in the README index, and tested in `tests/run.sh` (fake `sbatch`, `sinfo` and `squeue` live in the test's PATH).
7. Write for any nano member: no personal home paths (`/global/home/users/<name>`), personal checkouts, accounts other than `nano`, or credentials. Use `$HOME`, `$USER` and placeholders such as `CHECKOUT`. Personal conventions belong in your own `$USER-lrc` skill (`install.sh --personal`).
8. Write prose as unwrapped markdown, one line per paragraph or list item.
