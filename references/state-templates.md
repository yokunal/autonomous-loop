# State file templates

Copy these into `<project>/.loop/` (or run `scripts/init_loop.sh`). Keep each file small and plain Markdown so any agent can read and edit it.

## Contents
- GOAL.md
- TASKS.md
- STATE
- STATUS.md
- LOG.md entry format
- DECISIONS.md
- ERRORS.md
- PROMPT.md (resume prompt)
- FINAL_REPORT.md

---

## GOAL.md

```markdown
# Goal
<One paragraph: what must exist or be true when this is done.>

## Acceptance criteria (each must be checkable by a command, test, or measured output)
1. <criterion, and the command or test that proves it>
2. ...
N. `scripts/verify.sh` exits 0 in full mode.

## Constraints
- Stack / versions: ...
- Forbidden: ...
- Inputs / source documents: PRD.md, ...

## Safety tier
Tier 1 (sandbox). <Change to 2 or 3 only if explicitly intended, and name what is allowed.>

## Budgets
- Wall-clock: 8 hours
- Iterations: 60
- Attempts per task: 5
- Money: 0

## Out of scope
- ...
```

## TASKS.md

```markdown
# Tasks (work top to bottom, one at a time)
- [ ] T00 Environment survey and bootstrap
- [ ] T01 Walking skeleton: project layout, run command, first test, verify gate
- [ ] T02 ...
- [ ] T0N Full verify, packaging / deployment (if any), FINAL_REPORT.md

## Notes
- BLOCKED items use: `- [!] T07 title: BLOCKED because ...; fallback in place: ...`
```

Task design tips: each task fits in one iteration; each has a way to check it; the first runnable thing comes early; risky or uncertain tasks (new library, external download) come before polish.

## STATE

One line only, no extra text:

```
RUNNING
```
or `FINISHED 2026-10-23T06:41:00+05:30` or `STOPPED budget exhausted: 8h`.

## STATUS.md (overwrite every iteration)

```markdown
# Status
- updated: <date -Is>
- iteration: <n>
- current task: <Txx title>
- last gate result: <quick|full> <pass|fail: stage>
- consecutive failures on this task: <n>
- tasks: <done>/<total> done, <blocked> blocked
- started: <first LOG timestamp>
```

## LOG.md entry format (append only)

```markdown
## Iter <n> | <date -Is> | T<id>
Plan: <1-2 lines>
Did: <what changed>
Result: <pass | fail: fingerprint>
Next: <next step>
```

## DECISIONS.md

```markdown
# Decisions made without the human
- <date> <decision>. Why: <one line>.

## Test changes (every edit to a test, threshold, or gate must be listed)
- <date> <file>: <what changed>. Why: <genuine reason>.
```

## ERRORS.md

```markdown
# Error fingerprints (append only)
| fingerprint | count | what was tried | what fixed it |
|---|---|---|---|
| ModuleNotFoundError: No module named X | 1 | pip install X | fixed |
```

## PROMPT.md (resume prompt used by the outer driver)

```markdown
You are an autonomous agent working in this project with no human available.
Follow the autonomous-loop skill (or `.loop/PROTOCOL.md` if skills are unavailable).
First read `.loop/STATE`. If it says FINISHED or STOPPED, do nothing and exit.
Otherwise resume: read `.loop/GOAL.md`, `TASKS.md`, `STATUS.md`, the tail of `LOG.md`, `ERRORS.md`, then run the loop.
Never ask questions. Never weaken tests. Obey budgets and safety tier in GOAL.md.
Work as many iterations as you can in this session, committing after each.
When the full gate passes or a stop condition is met, write `.loop/FINAL_REPORT.md` and set `.loop/STATE`.
```

## FINAL_REPORT.md

```markdown
# Final report
**Result:** SUCCESS | PARTIAL | FAILED, <one line why>
**Finished:** <timestamp> | **Iterations:** <n> | **Elapsed:** <h>

## Acceptance criteria
| # | Criterion | Result | Evidence (command / file / number) |
|---|---|---|---|

## What was built
<Where things are, how to run, test, stop.>

## Blocked or degraded
<Task, reason, workaround in place.>

## Decisions made without you
<From DECISIONS.md, summarized.>

## Known weaknesses
<Honest list.>

## Your next 5 steps (in order)
1. ...
```
