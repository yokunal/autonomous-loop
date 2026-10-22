# Unattended setup (all-night runs)

How to prepare a machine and launch the loop so it keeps running while you sleep.

## Contents
1. Honest limits
2. Machine preparation (EC2 or any Linux VPS)
3. Installing the skill
4. Permissions: removing prompts safely
5. The outer driver
6. Claude Code recipe
7. Antigravity recipe
8. Cost and safety caps
9. Before you go to sleep (checklist)
10. Morning checklist

---

## 1. Honest limits

- A skill is **instructions**, not a process. It makes the agent disciplined, but it cannot keep a session alive.
- An agent session ends when the model decides it is finished, hits a turn or token limit, crashes, or waits on a permission prompt.
- Persistence comes from two things together: the **state files** in `.loop/` (so any fresh session can resume) and the **outer driver** (so a fresh session is launched whenever one ends).
- If your agent only exists inside an IDE window with no command-line mode, there is no way to relaunch it automatically. Use big goals split into small tasks, auto-approve settings, and re-send the kickoff prompt if it stops.
- Check the flag names below against `--help` on your installed version. Tools change.

## 2. Machine preparation (EC2 or any Linux VPS)

Use a **dedicated, disposable machine**. Do not put production credentials, personal SSH keys, or cloud admin keys on it.

```bash
# resources
nproc; free -m; df -h /
# swap if RAM is small (needs sudo)
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
# basics
sudo apt-get update && sudo apt-get install -y git tmux build-essential curl unzip jq lsof
# python helpers (optional)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Recommended minimum for builds involving ML models or browsers: 2 vCPU and 4 GB RAM plus 20 GB disk.

Network: open only the ports you need in the security group yourself. Never give the agent cloud admin rights.

Run everything inside `tmux` (or `nohup`) so closing your SSH session does not kill it:

```bash
tmux new -s loop
# ... start the driver (section 5) ...
# detach with Ctrl+b then d; reattach later with: tmux attach -t loop
```

## 3. Installing the skill

Copy the whole `autonomous-loop/` folder (SKILL.md, scripts/, references/).

| Agent | Global location | Project location |
|---|---|---|
| Claude Code | `~/.claude/skills/autonomous-loop/` | `<project>/.claude/skills/autonomous-loop/` |
| Antigravity | `~/.gemini/antigravity/skills/autonomous-loop/` (some versions use a different global folder under `~/.gemini/`) | `<project>/.agent/skills/autonomous-loop/` or `<project>/.agents/skills/autonomous-loop/` |

Locations differ between versions. If the skill does not show up, check the agent's own skills documentation or settings, and put the copy in both `.agent/skills` and `.agents/skills`.

```bash
chmod +x autonomous-loop/scripts/*.sh
```

Add a one-line pointer to the project rules file (`CLAUDE.md`, `AGENTS.md`, or `.agents/rules/`):

```
For autonomous or overnight work, follow the autonomous-loop skill and .loop/PROTOCOL.md.
```

## 4. Permissions: removing prompts safely

The #1 reason overnight runs stall is a permission prompt nobody answers.

- **Claude Code**: for non-interactive runs use either a narrow allow list (`--allowedTools`, or `permissions.allow` in `.claude/settings.json`) plus a permission mode, or the flag that skips all prompts (`--dangerously-skip-permissions`). The skip-all flag is only reasonable on the disposable machine from section 2, never on a laptop or a machine with real credentials. The driver requires `I_UNDERSTAND_SANDBOX=1` before it will add that flag.
- **Antigravity**: set the terminal command policy to auto-execute (the setting is usually called something like "Terminal Command Auto Execution" with an "always proceed" or "turbo" option) and set the review policy so edits do not wait for approval. Also check any allow and deny lists. Exact names vary by version.
- In both: keep a **deny list** for dangerous commands if the tool supports one (`rm -rf /`, `sudo rm`, `mkfs`, `dd`, `shutdown`, `reboot`, `aws ... delete`, `git push --force`).

## 5. The outer driver

`scripts/loop_driver.sh` relaunches the agent until the loop says it is done.

What it does:
1. Takes a lock so two drivers cannot run at once.
2. Each cycle: stops if `.loop/STATE` begins with `FINISHED` or `STOPPED`; stops if the time budget (`MAX_HOURS`) or run budget (`MAX_RUNS`) is used up.
3. Runs one agent session with `.loop/PROMPT.md` under a per-session `timeout`.
4. Compares a progress fingerprint (git HEAD plus a hash of `TASKS.md` plus a hash of `LOG.md`) before and after. If nothing changed for `MAX_IDLE_RUNS` sessions in a row, it writes `STOPPED no progress` and exits (circuit breaker).
5. Backs off when a session fails fast (for example a rate limit), then continues.
6. Logs everything to `.loop/driver.log`.

Settings (environment variables):

| Variable | Default | Meaning |
|---|---|---|
| `PROJECT_DIR` | current directory | Project root |
| `MAX_HOURS` | 8 | Total time budget |
| `MAX_RUNS` | 30 | Max agent sessions |
| `MAX_IDLE_RUNS` | 3 | Sessions with no progress before stopping |
| `RUN_TIMEOUT` | 5400 | Seconds allowed per session |
| `PAUSE` | 20 | Seconds between sessions |
| `AGENT_CMD` | (claude, see below) | Any shell command that runs one agent session; it can read `$PROMPT_FILE` |
| `MAX_TURNS` | 80 | Claude Code `--max-turns` |
| `CLAUDE_FLAGS` | empty | Extra Claude Code flags (permissions, budget, model) |
| `I_UNDERSTAND_SANDBOX` | unset | Set to `1` to add `--dangerously-skip-permissions` automatically |

## 6. Claude Code recipe

```bash
cd ~/myproject
bash ~/.claude/skills/autonomous-loop/scripts/init_loop.sh .      # creates .loop/ and a failing verify stub
# edit .loop/GOAL.md (or just write your request in .loop/GOAL.md and point to PRD.md)
export I_UNDERSTAND_SANDBOX=1      # only on the disposable machine
export MAX_HOURS=8 MAX_RUNS=30
tmux new -s loop
bash ~/.claude/skills/autonomous-loop/scripts/loop_driver.sh
```

Useful Claude Code flags (verify with `claude --help`): `-p` for non-interactive print mode, `--max-turns` to cap agent turns per session, `--max-budget-usd` to cap spend per session, `--permission-mode`, `--allowedTools`, `--output-format`, `--continue` / `--resume`. Example: `CLAUDE_FLAGS="--max-budget-usd 5" bash scripts/loop_driver.sh`.

First-run intake happens automatically: the first session sees there is no filled-in `GOAL.md` and runs Phase 0 from SKILL.md. For best results, fill `GOAL.md` yourself or point it to your PRD.

## 7. Antigravity recipe

1. Install the skill and rules pointer (section 3) and set auto-execute policies (section 4).
2. Open the project, start a new agent conversation, and paste the kickoff prompt:

```
Use the autonomous-loop skill. Goal is in PRD.md (or .loop/GOAL.md if it exists).
I am asleep and cannot answer questions. Run the loop until the verify gate passes
or a stop condition is hit. Write .loop/FINAL_REPORT.md at the end.
```

3. If Antigravity has a command-line mode in your version, wrap it with the driver:
```bash
AGENT_CMD='<antigravity cli command that takes the prompt from "$PROMPT_FILE">' bash scripts/loop_driver.sh
```
Check its help for the exact syntax. If there is no CLI, the IDE session is the only runner: keep tasks small, and re-send the kickoff prompt if it stops (the state files make that safe).

4. Antigravity can run Claude or Gemini models. The skill is model-agnostic.

## 8. Cost and safety caps

- Time: `MAX_HOURS`, `MAX_RUNS`, `RUN_TIMEOUT`.
- Money: `--max-budget-usd` (Claude Code), provider-side spending limits and alerts in the console of whichever API account is used, and budgets in `GOAL.md` (default zero spend on external services).
- Runaway loops: `MAX_IDLE_RUNS` circuit breaker and the skill's own stop conditions.
- Blast radius: disposable machine, no real credentials, Tier 1 safety, snapshot or AMI before long runs if the machine holds anything you care about.
- Cloud bill guard: set an AWS Budget alert in the console yourself before sleeping.

## 9. Before you go to sleep (checklist)

- [ ] Goal and acceptance criteria written (`.loop/GOAL.md` or a PRD the agent will read)
- [ ] Machine disposable, no real secrets on it, swap and disk checked
- [ ] Permission prompts removed (section 4) and deny list set
- [ ] Spending caps and AWS Budget alert set
- [ ] Driver started inside `tmux`, and you saw at least one full cycle begin (check `tail -f .loop/driver.log` and `bash scripts/status.sh`)
- [ ] Security group opens only what you need
- [ ] You know where `.loop/FINAL_REPORT.md` will appear

## 10. Morning checklist

```bash
bash ~/.claude/skills/autonomous-loop/scripts/status.sh ~/myproject
cat ~/myproject/.loop/FINAL_REPORT.md
```

1. Read `STATE` and the final report first, then `DECISIONS.md` and the list of blocked tasks.
2. Run the full gate yourself: `bash scripts/verify.sh`.
3. Look at real outputs (open the app, look at generated files and screenshots in `debug/`). The gate catches a lot, not everything.
4. Review `git log` and the diff of any test changes listed in `DECISIONS.md`.
5. Rotate any key that may have leaked, stop the driver (`tmux kill-session -t loop`), and stop any services you do not need.
