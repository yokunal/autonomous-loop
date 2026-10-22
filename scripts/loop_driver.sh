#!/usr/bin/env bash
# Universal outer loop: relaunches a fresh agent session until .loop/STATE says FINISHED/STOPPED,
# a budget runs out, or several sessions in a row make no progress.
# Usage: PROJECT_DIR=~/proj [MAX_HOURS=8] bash loop_driver.sh
set -uo pipefail

PROJECT_DIR="${PROJECT_DIR:-$PWD}"
MAX_RUNS="${MAX_RUNS:-10}"
MAX_HOURS="${MAX_HOURS:-2}"
MAX_IDLE_RUNS="${MAX_IDLE_RUNS:-3}"
RUN_TIMEOUT="${RUN_TIMEOUT:-3600}"
MAX_BUDGET_USD="${MAX_BUDGET_USD:-5.00}"
PAUSE="${PAUSE:-20}"
MAX_TURNS="${MAX_TURNS:-80}"
CLAUDE_FLAGS="${CLAUDE_FLAGS:-}"
AGENT_CMD="${AGENT_CMD:-}"
AGENT_TYPE="${AGENT_TYPE:-}"
AGY_FLAGS="${AGY_FLAGS:-}"
AUTO_ROLLBACK="${AUTO_ROLLBACK:-1}"

cd "$PROJECT_DIR" || { echo "cannot cd to $PROJECT_DIR"; exit 1; }
[ -d .loop ] || { echo ".loop/ not found. Run init_loop.sh first."; exit 1; }
export PROMPT_FILE="$PWD/.loop/PROMPT.md"
LOG=".loop/driver.log"
log() { echo "[$(date -Is)] $*" | tee -a "$LOG"; }

# single instance
exec 9>.loop/driver.lock
if ! flock -n 9; then echo "another driver is already running"; exit 1; fi

# agent command configuration
if [ -z "$AGENT_CMD" ]; then
  if [ "$AGENT_TYPE" = "agy" ] || [ "$AGENT_TYPE" = "antigravity" ] || (! command -v claude >/dev/null 2>&1 && command -v agy >/dev/null 2>&1); then
    if ! command -v agy >/dev/null 2>&1; then
      log "AGENT_TYPE=agy specified but 'agy' not found in PATH."
      exit 1
    fi
    FLAGS="$AGY_FLAGS"
    if [ "${I_UNDERSTAND_SANDBOX:-0}" = "1" ]; then FLAGS="$FLAGS --dangerously-skip-permissions"; fi
    if [ -z "$FLAGS" ]; then
      log "WARNING: no permission flags. The agent may stall on prompts. Set AGY_FLAGS or I_UNDERSTAND_SANDBOX=1 on a disposable machine."
    fi
    AGENT_CMD='agy -p "$(cat "$PROMPT_FILE")" --mode auto '"$FLAGS"
  elif command -v claude >/dev/null 2>&1; then
    FLAGS="$CLAUDE_FLAGS"
    if [ "${I_UNDERSTAND_SANDBOX:-0}" = "1" ]; then FLAGS="$FLAGS --dangerously-skip-permissions"; fi
    if [ -n "$MAX_BUDGET_USD" ] && ! echo "$FLAGS" | grep -q -- '--max-budget-usd'; then
      FLAGS="--max-budget-usd $MAX_BUDGET_USD $FLAGS"
    fi
    if [ -z "$FLAGS" ]; then
      log "WARNING: no permission flags. The agent will stall on prompts. Set CLAUDE_FLAGS, or I_UNDERSTAND_SANDBOX=1 on a disposable machine."
    fi
    AGENT_CMD='claude -p "$(cat "$PROMPT_FILE")" --max-turns '"$MAX_TURNS $FLAGS"
  else
    log "No AGENT_CMD set and neither 'claude' nor 'agy' found in PATH. Set AGENT_CMD to a command that runs one agent session."
    exit 1
  fi
fi

fingerprint() {
  # Progress = new commits, edited task list/log, or changed working tree.
  # The driver's own files (session logs, driver log, STATE, STATUS heartbeat) are excluded on purpose.
  {
    git rev-parse HEAD 2>/dev/null || echo nohead
    sha256sum .loop/TASKS.md .loop/LOG.md 2>/dev/null | awk '{print $1}'
    git status --porcelain 2>/dev/null | grep -vE '\.loop/(session-|driver|STATE|STATUS)' | sha256sum | awk '{print $1}'
    git diff HEAD -- . ':!.loop/STATE' ':!.loop/STATUS.md' 2>/dev/null | sha256sum | awk '{print $1}'
  } | tr '\n' ' '
}

state_done() { head -c 20 .loop/STATE 2>/dev/null | grep -qE '^(FINISHED|STOPPED)'; }
set_state() { echo "$1" > .loop/STATE; }

START=$(date +%s)
DEADLINE=$(( START + MAX_HOURS * 3600 ))
runs=0; idle=0

log "driver start: project=$PWD max_runs=$MAX_RUNS max_hours=$MAX_HOURS budget_usd=$MAX_BUDGET_USD idle_limit=$MAX_IDLE_RUNS"

while true; do
  if state_done; then log "STATE is terminal: $(cat .loop/STATE). Exiting."; break; fi
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then set_state "STOPPED time budget ${MAX_HOURS}h exhausted"; log "time budget exhausted"; break; fi
  if [ "$runs" -ge "$MAX_RUNS" ]; then set_state "STOPPED run budget ${MAX_RUNS} exhausted"; log "run budget exhausted"; break; fi

  runs=$((runs+1))
  before="$(fingerprint)"
  t0=$(date +%s)

  # Checkpoint before session
  checkpoint_tag="loop-checkpoint-$runs"
  if git rev-parse HEAD >/dev/null 2>&1; then
    git tag -f "$checkpoint_tag" HEAD >/dev/null 2>&1 || true
    log "safety checkpoint created: $checkpoint_tag"
  fi

  log "session $runs starting"
  timeout "$RUN_TIMEOUT" bash -c "$AGENT_CMD" >> ".loop/session-$runs.log" 2>&1
  rc=$?
  dur=$(( $(date +%s) - t0 ))
  log "session $runs ended rc=$rc after ${dur}s (output: .loop/session-$runs.log)"

  # Safety check: if git index was destroyed or working tree corrupted with rc!=0
  if [ "$rc" -ne 0 ] && [ "$AUTO_ROLLBACK" = "1" ] && [ -n "${checkpoint_tag:-}" ]; then
    if ! git status >/dev/null 2>&1; then
      log "WARNING: git status corrupted after session $runs; attempting recovery to $checkpoint_tag"
      git reset --hard "$checkpoint_tag" >> "$LOG" 2>&1 || true
    fi
  fi

  # keep only recent session logs
  ls -1t .loop/session-*.log 2>/dev/null | tail -n +11 | xargs -r rm -f

  after="$(fingerprint)"
  if [ "$before" = "$after" ]; then idle=$((idle+1)); log "no progress detected ($idle/$MAX_IDLE_RUNS)"; else idle=0; fi
  if [ "$idle" -ge "$MAX_IDLE_RUNS" ]; then set_state "STOPPED no progress in $MAX_IDLE_RUNS sessions"; log "circuit breaker tripped"; break; fi

  # fast failure (rate limit, crash, auth): back off before retrying
  if [ "$dur" -lt 30 ] && [ "$rc" -ne 0 ]; then
    back=$(( PAUSE * 3 )); log "fast failure; backing off ${back}s"; sleep "$back"
  else
    sleep "$PAUSE"
  fi
done

log "driver finished after $runs sessions. Run scripts/status.sh for the summary."
