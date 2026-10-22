---
name: autonomous-loop
description: Run an AI coding agent unattended in a disciplined loop until a measurable goal is achieved, with self-checking, self-repair, budgets, safety limits, and a morning handoff report. Use this skill whenever the user says things like "run in a loop until done", "keep going until the tests pass", "work overnight", "while I sleep", "autonomous", "unattended", "don't stop until it works", "build this whole project by yourself", or hands over a PRD / spec / long task list for the agent to finish alone. Also use it for any long multi-step build, migration, refactor, bug backlog, data pipeline, or deployment where the agent must survive errors, context resets, and permission friction without a human. Works for any language, stack, and project, in Claude Code, Claude in Antigravity, and other agents that read SKILL.md or AGENTS.md. Use it even if the user does not say the word "loop".
---

# Autonomous Loop

A protocol for finishing a goal **without a human in the room**. The human may be asleep, away, or unreachable for hours. Your memory is the files in `.loop/`, not your context window. Your judge is a machine-checkable gate, not your opinion.

Read this whole file at the start of **every** session and iteration. If you were interrupted or your context was reset, go straight to section 12 (Resuming).

Detail files (read only when needed):
- `references/state-templates.md`: exact templates for every `.loop/` file
- `references/verify-patterns.md`: how to build the verify gate for each stack and for non-code goals
- `references/failure-playbook.md`: a large table of symptoms and fixes
- `references/unattended-setup.md`: server prep, permission settings, drivers, cost caps, morning checklist
- `scripts/init_loop.sh`, `scripts/loop_driver.sh`, `scripts/status.sh`: helpers

---

## 1. Prime rules (never violate)

1. **Never ask the human a question and wait.** If something is ambiguous, choose the most reasonable option, write it in `.loop/DECISIONS.md` with one line of reasoning, and continue. Questions go in the final report.
2. **The gate is the judge.** "Done" means the verify gate exits 0 and every acceptance criterion in `.loop/GOAL.md` is met. Not "it looks right to me".
3. **Never move the goalposts.** Do not delete, skip, or weaken tests, lower thresholds, edit the gate to pass, or shrink the goal just to get green. A genuinely wrong test may be fixed, but log it under "Test changes" in `DECISIONS.md` with the reason. Passing by cheating is failure.
4. **Never block the terminal.** Every command that can hang gets `timeout`. Servers and long jobs run in the background with logs. Pass `-y`, `--yes`, `CI=1`, `DEBIAN_FRONTEND=noninteractive`, `< /dev/null` where relevant.
5. **Stay inside the project.** Work only inside the project directory plus normal caches. Never touch `~/.ssh`, cloud credentials, system config, other projects, or other users' files.
6. **Spend no money and make no irreversible external changes** unless `GOAL.md` explicitly allows it (see Safety Tiers, section 8). That covers paid APIs, cloud resources, live payments, emails/messages to real people, pushing to production, and force-pushing.
7. **No secrets in git or logs.** Use `.env` (gitignored) and `.env.example` with fake values.
8. **Commit small and often.** The repo must always be recoverable to a last known good state.
9. **Do not loop forever.** Obey the budgets and stop conditions in section 7. Spinning burns money and proves nothing.
10. **Be honest.** A truthful "PARTIAL, here is what is broken" beats a fake "SUCCESS".

## 2. State directory (your external memory)

Everything lives in `<project>/.loop/`. Create it with `bash scripts/init_loop.sh` (path relative to this skill folder) or by hand from `references/state-templates.md`.

| File | Purpose |
|---|---|
| `GOAL.md` | Goal, acceptance criteria, constraints, budgets, safety tier. Written once in Intake, rarely edited |
| `TASKS.md` | Checklist: `- [ ] T07 title`, `- [x]` done, `- [!] BLOCKED reason`. The loop's work queue |
| `STATE` | One line: `RUNNING`, `FINISHED`, or `STOPPED <reason>`. The outer driver reads this |
| `STATUS.md` | Heartbeat, overwritten every iteration: timestamp, iteration number, current task, last gate result, consecutive failure count |
| `LOG.md` | Append-only, one short entry per iteration (under 10 lines) |
| `DECISIONS.md` | Every judgment call, plus a "Test changes" section |
| `ERRORS.md` | Append-only error fingerprints and what fixed them |
| `PROTOCOL.md` | A copy of this file, so agents without skill support can still read the rules |
| `PROMPT.md` | The resume prompt used by the outer driver |
| `FINAL_REPORT.md` | Written at the end |

## 3. Phase 0: Intake (first session only, skip if `.loop/GOAL.md` exists)

Do this in order, without asking the human anything:

1. **Find the goal.** Use the user's message. If they pointed to a file (`PRD.md`, `README`, `SPEC`, an issue list), read it fully. If the goal is vague, write the most sensible concrete interpretation and log it in `DECISIONS.md`.
2. **Survey the environment.** Run and record in `LOG.md`: OS, `nproc`, `free -m`, `df -h /`, language runtimes and versions, package managers, `git status`, whether passwordless `sudo` works (`sudo -n true`), network access (`curl -sI --max-time 5 https://pypi.org`), and what already exists in the project.
3. **Write `GOAL.md`.** Include:
   - One-paragraph goal
   - **Acceptance criteria**: a numbered list where every item is checkable by a command, a test, or an inspected output file. If an item cannot be checked mechanically, rewrite it until it can (see `references/verify-patterns.md`, "Non-code goals").
   - Constraints (stack, versions, forbidden things)
   - **Safety tier** (section 8), default Tier 1
   - **Budgets** (section 7), defaults if not given: 8 hours, 60 iterations, 5 attempts per task
4. **Build the verify gate** at `scripts/verify.sh` (or `make verify`). It must exit non-zero for any unmet criterion and print which stage failed. Pick the pattern for the stack from `references/verify-patterns.md`. An unconfigured gate must fail, never pass by default. Provide `--quick` (fast checks only) and full modes.
5. **Write `TASKS.md`**: break the goal into small tasks, each doable in one iteration (about 10 to 30 minutes), ordered so something runnable exists as early as possible (walking skeleton first). Last tasks are always: full verify, deployment or packaging if relevant, final report.
6. **Commit** (`git add -A && git commit -m "loop: intake"`), set `STATE` to `RUNNING`, and start the loop.

## 4. The loop (one iteration)

```
1. ORIENT   Read STATE, STATUS.md, TASKS.md, the last 40 lines of LOG.md, and ERRORS.md.
            Run `git status` and `git log --oneline -5`. Run `scripts/verify.sh --quick`.
            Overwrite STATUS.md (timestamp via `date -Is`, iteration number).
            If STATE is FINISHED or STOPPED, do nothing and exit.
2. HEALTH   If the repo is broken or the gate got worse than the last good tag, fix or revert FIRST.
3. CHOOSE   Take the first unchecked, non-blocked task. Never start two tasks at once.
4. PLAN     Write 3 to 6 lines in LOG.md: what, how, and how I will know it worked.
5. TEST     For code tasks, write or extend the test first. For other tasks, define the check first.
6. BUILD    Smallest change that satisfies the check.
7. VERIFY   Run the relevant checks with `timeout`, then `scripts/verify.sh --quick`.
8a. PASS    Commit (`Txx: title`), tick the task, tag good states (`git tag -f good-<time>` when the full gate passes),
            append to LOG.md, reset the consecutive failure count, go to 1.
8b. FAIL    Anti-stuck protocol (section 6). Never move on silently.
9. DONE?    When all tasks are ticked or blocked: run the FULL gate.
            Exit 0 and all criteria met: Finishing (section 11).
            Otherwise add one task per failing criterion and continue.
```

Rules of thumb:
- One task per iteration. If a task grows, split it in `TASKS.md`.
- After every successful iteration there should be a commit. If two iterations pass with no commit, you are drifting.
- Prefer boring, well-known solutions that work unattended over clever ones.
- If two approaches are equal, choose the one that fails loudly and recovers easily.
- Visual or UX work: save screenshots or rendered output to a `debug/` folder and actually inspect them at least once before calling the task done.

## 5. The verify gate (summary)

The gate is the single most important design decision. Full recipes are in `references/verify-patterns.md`. Principles:

- **Objective**: exit code 0 or not. No human judgment inside the gate.
- **Layered**: lint, then unit tests, then integration or smoke tests, then (if there is a running service) a live health check and an end-to-end flow.
- **Hard to game**: real behaviors, negative cases, and property checks, not only "does not crash".
- **Fast quick-mode** for every iteration, **full mode** before declaring done.
- **Self-checking outputs**: anything the product produces (files, images, reports, API responses) is re-opened and measured against the spec by a validator, in tests and where it matters at runtime.
- **Immutable by default**: only change the gate or tests under rule 3.

## 6. Anti-stuck protocol (self-repair)

### 6.1 Error fingerprinting
When something fails, reduce it to a fingerprint: exception type plus the key message, with numbers, paths, and ids removed. Look it up in `ERRORS.md`.

- **First occurrence**: append the fingerprint, apply the most likely fix.
- **Second occurrence**: you are repeating yourself. Read the full traceback and the relevant source or docs (help text, `--help`, package docs, web search if available). Try a genuinely different fix.
- **Third occurrence (3-strike)**: change strategy completely. Use the ladder below. Log the new strategy in `DECISIONS.md`.
- **After 5 failed attempts on one task**: mark it `- [!] BLOCKED <reason>`, implement the best graceful fallback, commit, and move to the next task. Revisit blocked tasks at the end if budget remains.

### 6.2 Strategy ladder (go down one step per strike)
1. Retry with the obvious fix.
2. Diagnose properly: reproduce in the smallest case, read the full error, check versions and environment.
3. Try an alternative library, algorithm, or configuration.
4. Simplify: reduce scope, hardcode one path, make it work for one case, then generalize.
5. Fallback: a degraded but working version (for example a simpler detector, a cached asset, a stub with a clear TODO and a test that documents the gap).
6. Block and move on.

### 6.3 Regression guard
If a change makes previously passing checks fail and you cannot fix it within 3 attempts: `git stash` or `git reset --hard <last good tag>` and redo the work in a smaller step.

### 6.4 Thrash detector
If you rewrite the same file three times without the failing check changing, stop. Write a 5-line analysis in `LOG.md` of what is actually failing (not what you assumed), then follow the ladder.

### 6.5 Environment problems
Most overnight failures are environmental, not logical: missing system libraries, wrong runtime version, full disk, out of memory, port in use, blocked network, hung processes, permission prompts. Consult `references/failure-playbook.md`.

## 7. Budgets and stop conditions

Defaults (override in `GOAL.md`):

| Budget | Default |
|---|---|
| Wall-clock | 8 hours since the first `LOG.md` entry (check with `date`) |
| Iterations | 60 |
| Attempts per task | 5 |
| Consecutive iterations with no commit and no new idea | 3 |
| Disk | stop above 90 percent after cleaning caches |
| Money | 0 unless `GOAL.md` sets a cap; never exceed it |

Stop and run Finishing when **any** is true:
- Gate exits 0 and all acceptance criteria are met (**success**)
- Any budget is exhausted
- Every remaining task is BLOCKED
- A Tier violation would be required to continue

## 8. Safety tiers (set in `GOAL.md`, default Tier 1)

| Tier | Allowed | Forbidden |
|---|---|---|
| **1 Sandbox (default)** | Read and write inside the project, install packages in a venv or `node_modules`, run local servers and tests, git commits locally | Anything outside the project, system package removal, network writes to third parties, cloud changes, paid APIs, live payments or credentials, pushing to remotes |
| **2 Project plus network** | Tier 1 plus API calls to free or explicitly named services, downloading dependencies and models, `git push` to a named non-main branch | Production deploys, spending, deleting remote resources |
| **3 Deploy** | Tier 2 plus deploy to a named environment listed in `GOAL.md`, with a rollback command recorded first | Anything not named in `GOAL.md` |

Hard bans in every tier: `rm -rf /`, `rm -rf ~`, `rm -rf` on any path you have not printed and checked to be inside the project or a known cache, `chmod -R 777`, `curl ... | sh` from unknown sources (well-known installers from official domains such as `uv` or `nvm` are acceptable), disabling firewalls, editing SSH config, creating users, changing IAM or security groups, printing environment secrets, force-push, rewriting shared history.

Before any delete command, print the exact path and confirm it is inside the project or a known cache directory.

If the next step needs something outside your tier, do not do it. Log it, implement the nearest safe alternative, and list it in the final report.

## 9. Context hygiene (long runs)

- Re-read state files each iteration. Never rely on remembering.
- Do not dump huge outputs: pipe through `tail -n 60`, `head`, or `grep`, and write full output to `logs/` files.
- Keep `LOG.md` entries short. Keep `TASKS.md` current. If `LOG.md` grows beyond about 400 lines, move the older part to `.loop/LOG.archive.md`.
- Prefer file edits to retyping large files. Prefer small commits to big ones.
- If you notice you have lost the thread, stop and do section 12.

## 10. Process management

- Start servers with `nohup <cmd> > logs/<name>.log 2>&1 &` and record the pid in `run/<name>.pid`, or use `tmux new -d -s <name>` when available.
- Before starting a service, check the port (`ss -ltnp | grep :<port>` or `lsof -i :<port>`) and stop stale processes you started earlier.
- Health-check with a timeout (`curl -fsS --max-time 5`), and poll with a deadline instead of fixed sleeps.
- Always stop test servers you started. Check with `ps aux | grep <name>` before moving on.
- Each shell tool call may be a fresh shell: re-activate virtualenvs and re-export variables in every command sequence.
- For a service that must stay up after you finish, use systemd if passwordless sudo exists, else a small watchdog loop (`nohup`) that health-checks every 30 seconds and restarts on failure. Truncate logs over 50 MB.

## 11. Finishing

1. Run the full gate one last time. Save the output to `logs/final_verify.txt`.
2. If there is a service, make sure it is running under supervision and the health check passes. Record how to reach it.
3. Write `.loop/FINAL_REPORT.md` (template in `references/state-templates.md`): result in one line (SUCCESS, PARTIAL, or FAILED), table of each acceptance criterion with pass or fail plus evidence, what was built and where, how to run, test, and stop it, blocked tasks and workarounds, decisions made without the human, known weaknesses, and the top 5 next steps for the human in order.
4. Write `STATE`: `FINISHED <timestamp>` for success, or `STOPPED <reason>` otherwise.
5. Update `STATUS.md`. Then **stop making changes**.

## 12. Resuming after interruption or context reset

You may be a fresh session with no memory. Do this:
1. Read `.loop/STATE`. If `FINISHED` or `STOPPED`, report that and exit.
2. Read `GOAL.md`, `TASKS.md`, `STATUS.md`, the tail of `LOG.md`, `ERRORS.md`, `DECISIONS.md`.
3. `git status`, `git log --oneline -10`. If there are uncommitted changes, run the quick gate: keep the work if it passes, otherwise `git stash` it and note this in `LOG.md`.
4. Check for stray processes and ports from the previous session and clean them (only ones you started).
5. Continue from step 1 of the loop. **Never restart the project from scratch.**

## 13. Using this in different agents

- **Claude Code**: skills load from `~/.claude/skills/<name>/` (global) or `.claude/skills/<name>/` (project). Also put a one-line pointer in `CLAUDE.md`: "For autonomous or overnight work follow the autonomous-loop skill and `.loop/PROTOCOL.md`." Subagents can be used for independent checks, but keep a single writer for `.loop/` files.
- **Antigravity (Claude or Gemini models)**: skills load from `.agent/skills/<name>/` or `.agents/skills/<name>/` in the workspace (the folder name depends on the version) or from a global skills folder under `~/.gemini/`. Put the same pointer in the workspace rules file (`AGENTS.md` or `.agents/rules/`). Skills are auto-selected by description, so also name the skill explicitly in your kickoff prompt.
- **Any other agent**: no skill support needed. Copy `.loop/PROTOCOL.md` into its rules file and use `.loop/PROMPT.md` as the kickoff prompt.

Always **name the skill in the kickoff prompt**. Auto-triggering is helpful but not guaranteed.

## 14. Running unattended for real

A single agent session ends when the model thinks it is done, hits a turn or token limit, crashes, or waits on a permission prompt. A skill cannot prevent that by itself. For all-night runs:

1. Remove permission friction safely (auto-approve terminal commands inside an isolated machine). See `references/unattended-setup.md`.
2. Use the **outer driver** `scripts/loop_driver.sh`. It re-launches a fresh agent session with `.loop/PROMPT.md` whenever one ends, until `STATE` says `FINISHED` or `STOPPED`, a time or run budget is hit, or there are several runs in a row with no progress. Fresh sessions resume from `.loop/` thanks to section 12.
3. In the morning run `bash scripts/status.sh <project>` and read `.loop/FINAL_REPORT.md`.

If the agent only runs inside an IDE with no command-line mode, the driver cannot relaunch it. In that case give it a larger work budget per session, keep tasks small, and re-send the kickoff prompt if it stops.

## 15. Anti-pattern checklist (self-audit each iteration)

- Did I ask the human something? Remove it and decide.
- Did I touch tests or thresholds? Log it, or revert.
- Did a command run without `timeout`? Fix it.
- Did I start a second task before finishing the first? Stop and finish one.
- Am I repeating a fix from `ERRORS.md`? Go down the ladder.
- Did I leave a server or process running by accident? Clean up.
- Is the gate truly objective, and does it fail when unconfigured?
- Am I claiming success without a passing full gate? Do not.
- Would the human, reading `FINAL_REPORT.md` cold in the morning, know exactly what is true?
