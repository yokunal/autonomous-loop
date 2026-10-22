#!/usr/bin/env bash
# Scaffold the .loop/ state directory in a project.
# Usage: bash init_loop.sh [project_dir]
# Safe to re-run: never overwrites existing files.
set -euo pipefail

DIR="${1:-.}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$DIR"
cd "$DIR"

[ -d .git ] || git init -q -b main 2>/dev/null || git init -q
mkdir -p .loop logs scripts

write_if_missing() {  # write_if_missing <path>  (content from stdin)
  if [ -e "$1" ]; then cat >/dev/null; echo "keep   $1"; else cat > "$1"; echo "create $1"; fi
}

NOW="$(date -Is)"

write_if_missing .loop/GOAL.md <<'EOT'
# Goal
<One paragraph: what must exist or be true when this is done. Or: "Build what is described in PRD.md".>

## Acceptance criteria (each must be checkable by a command, test, or measured output)
1. <criterion and the command/test that proves it>
2. `scripts/verify.sh` exits 0 in full mode.

## Constraints
- Stack / versions:
- Forbidden:
- Source documents: PRD.md

## Safety tier
Tier 1 (sandbox).

## Budgets
- Wall-clock: 2 hours (default)
- Iterations: 25
- Attempts per task: 3
- Money: $5.00 max (0 for Tier 1 sandbox)

## Out of scope
-
EOT

write_if_missing .loop/TASKS.md <<'EOT'
# Tasks (work top to bottom, one at a time)
- [ ] T00 Environment survey and bootstrap
- [ ] T01 Walking skeleton, first test, configure scripts/verify.sh
- [ ] T99 Full verify and .loop/FINAL_REPORT.md
EOT

write_if_missing .loop/STATE <<'EOT'
RUNNING
EOT

write_if_missing .loop/STATUS.md <<EOT
# Status
- updated: $NOW
- iteration: 0
- current task: none
- last gate result: none
- consecutive failures on this task: 0
- started: $NOW
EOT

write_if_missing .loop/LOG.md <<EOT
# Log (append only)
## Init | $NOW
Scaffolded by init_loop.sh
EOT

write_if_missing .loop/DECISIONS.md <<'EOT'
# Decisions made without the human

## Test changes (every edit to a test, threshold, or gate must be listed)
EOT

write_if_missing .loop/ERRORS.md <<'EOT'
# Error fingerprints (append only)
| fingerprint | count | what was tried | what fixed it |
|---|---|---|---|
EOT

write_if_missing .loop/PROMPT.md <<'EOT'
You are an autonomous agent working in this project with no human available.
Follow the autonomous-loop skill (or `.loop/PROTOCOL.md` if skills are unavailable).
First read `.loop/STATE`. If it says FINISHED or STOPPED, do nothing and exit.
Otherwise resume: read `.loop/GOAL.md`, `.loop/TASKS.md`, `.loop/STATUS.md`, the tail of `.loop/LOG.md`, `.loop/ERRORS.md`, then run the loop.
If `.loop/GOAL.md` is still the unfilled template, run Phase 0 (Intake) using PRD.md or the project files to define the goal.
Never ask questions. Follow Red-Green-Refactor: every task requires tests AND code quality/linter pass.
Do not introduce architectural slop or ugly hacks just to pass tests.
If verify fails 3 times on one task, run a Meta-Verification Audit on verify.sh or mark [!] BLOCKED.
Never weaken tests without logging in DECISIONS.md. Obey the budgets and safety tier in GOAL.md.
Work as many iterations as you can in this session, committing after each.
When the full gate passes or a stop condition is met, write `.loop/FINAL_REPORT.md` and set `.loop/STATE`.
EOT

# Copy the protocol so agents without skill support can read it
if [ ! -e .loop/PROTOCOL.md ]; then cp "$SKILL_DIR/SKILL.md" .loop/PROTOCOL.md; echo "create .loop/PROTOCOL.md"; else echo "keep   .loop/PROTOCOL.md"; fi

# A gate that FAILS until configured (never passes by default)
write_if_missing scripts/verify.sh <<'EOT'
#!/usr/bin/env bash
# Verification gate. Layered into:
# Stage 1: Correctness (Unit/Integration tests)
# Stage 2: Code Quality (Types & Linters: tsc, eslint, ruff, mypy)
# Stage 3: Cleanliness & Refactor Check (Formatting, unused code)
#
# Usage:
#   bash scripts/verify.sh --quick   (runs fast Stage 1 checks)
#   bash scripts/verify.sh           (runs full all-stage checks)
set -eo pipefail

MODE="${1:-full}"

echo "==> Stage 1: Correctness (Tests)"
# The agent must replace this stub in Phase 0 (see references/verify-patterns.md).
echo "VERIFY FAILED: NOT CONFIGURED. Edit scripts/verify.sh for this project."
exit 2

if [ "$MODE" = "full" ]; then
  echo "==> Stage 2: Code Quality (Linters & Types)"
  # Add: ruff check ., npm run lint, tsc --noEmit, etc.

  echo "==> Stage 3: Cleanliness & Formatting"
  # Add: prettier --check, black --check, etc.
fi

echo "VERIFY PASSED ($MODE mode)"
exit 0
EOT
chmod +x scripts/verify.sh 2>/dev/null || true

# gitignore entries
touch .gitignore
for p in "logs/" "run/" "debug/" ".env" ".loop/driver.log" ".loop/driver.lock" ".loop/session-*.log" "__pycache__/" ".venv/" "node_modules/"; do
  grep -qxF "$p" .gitignore || echo "$p" >> .gitignore
done

# Default safety permissions (denylist for dangerous commands)
mkdir -p .claude
write_if_missing .claude/settings.json <<'EOT'
{
  "permissions": {
    "deny": [
      "rm -rf /",
      "rm -rf ~",
      "git push --force*",
      "git reset --hard*",
      "mkfs*",
      "dd if=*"
    ]
  }
}
EOT

git add -A >/dev/null 2>&1 || true
git -c user.name="${GIT_AUTHOR_NAME:-loop-agent}" -c user.email="${GIT_AUTHOR_EMAIL:-loop@localhost}" \
  commit -q -m "loop: scaffold" >/dev/null 2>&1 || true

echo
echo "Done. Next: fill .loop/GOAL.md (or point it at PRD.md), then start your agent or scripts/loop_driver.sh"
