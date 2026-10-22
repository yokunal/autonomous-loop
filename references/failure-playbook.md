# Failure playbook (generic, any project)

Look up the symptom, apply the fix, record the fingerprint in `.loop/ERRORS.md`. If the same symptom recurs, go down the strategy ladder in SKILL.md section 6.2.

## Contents
1. Environment and runtimes
2. Dependencies and packages
3. Network and downloads
4. Memory, CPU, disk
5. Processes, ports, hangs
6. Tests and the gate
7. Git
8. Agent and tool friction
9. Databases and data
10. Web, frontend, browsers
11. Secrets, auth, permissions
12. Long-running and unattended specifics
13. Quality problems (it works but is wrong)

---

## 1. Environment and runtimes

| Symptom | Likely cause | Action |
|---|---|---|
| `command not found` | Tool not installed or not on PATH | `which <tool>`, install via the project's package manager or `apt-get install -y` (if passwordless sudo), else user-space install (`uv`, `nvm`, `pyenv`, `~/.local/bin`) and add to PATH in each command |
| Wrong language version | System default too new or old | Install the required version with `uv python install`, `pyenv`, `nvm install`, `rustup`, `sdkman`; create the venv or env with it |
| Virtualenv not active in new shell | Each tool call may be a fresh shell | Prefix commands with `source .venv/bin/activate &&` or call `.venv/bin/python` directly |
| Locale or encoding errors | Minimal server locale | `export LC_ALL=C.UTF-8 LANG=C.UTF-8`, `PYTHONUTF8=1` |
| Timezone-dependent test failure | Server in UTC | Control the clock in tests or set `TZ` explicitly |
| `sudo: a password is required` | No passwordless sudo | Do not guess passwords. Use user-space alternatives and log it |

## 2. Dependencies and packages

| Symptom | Likely cause | Action |
|---|---|---|
| Build error compiling a wheel or native module | Missing compiler or headers | `apt-get install -y build-essential python3-dev libffi-dev libssl-dev` (if sudo); try a prebuilt wheel (`--only-binary=:all:`); pin an older version that ships wheels |
| No matching distribution found | Python version too new, wrong platform | Use a supported Python version; check the package's supported versions; try an alternative package |
| Import error after install | Installed into a different environment | `python -c "import sys; print(sys.executable)"`, reinstall with that interpreter's `-m pip` |
| Dependency conflict | Incompatible pins | Fresh venv, install the core package first, then others; relax over-tight pins; freeze working versions |
| `ImportError: libGL.so.1` or `libglib` missing | Headless server missing system libs | `apt-get install -y libgl1 libglib2.0-0`, or use the `-headless` variant of the package (for example `opencv-python-headless`) |
| npm `ERESOLVE` | Peer dependency conflicts | `npm install --legacy-peer-deps`, or align versions; commit the lockfile after success |
| Lockfile drift | Mixed package managers | Use one manager per project; delete the stray lockfile; reinstall |

## 3. Network and downloads

| Symptom | Likely cause | Action |
|---|---|---|
| Timeouts or connection reset on download | Flaky network, rate limit | Retry 3 times with backoff (5, 20, 60 seconds), `curl -L --retry 3 --retry-delay 5` |
| 403 / 429 from a registry or API | Rate limiting | Back off, cache the artifact locally, use a mirror, reduce parallelism |
| Model or asset download blocked | Egress restrictions | Try an alternative source or model, note the restriction, and implement a fallback so the product still runs. If the allowlist blocks it, record it for the human |
| DNS failures | Resolver issue | Retry; check `curl -sI https://pypi.org`; log and use cached packages if any |
| Offline entirely | No internet | Use only what is installed or vendored; mark network-dependent tasks BLOCKED with a fallback |

## 4. Memory, CPU, disk

| Symptom | Likely cause | Action |
|---|---|---|
| `Killed`, exit code 137, `MemoryError`, `Cannot allocate memory` | Out of memory | `free -m`; add swap if sudo (`fallocate -l 4G /swapfile; chmod 600; mkswap; swapon`); load heavy models once; downscale inputs early; reduce parallel workers and test concurrency; run heavy tests one at a time |
| Everything is very slow | CPU starved, swapping, too many workers | `top -bn1 | head -15`; kill stray processes; lower worker counts |
| `No space left on device` | Disk or inode exhaustion | `df -h`, `df -i`; clear `~/.cache/pip`, `~/.npm/_cacache`, build outputs, `logs/` and `data/tmp`, `docker system prune -af` only if Docker is used by this project; never delete outside project or cache dirs |
| Log files huge | Verbose logging | Rotate or truncate; lower log level; redirect noisy output to `/dev/null` |
| Test temp files pile up | Tests not cleaning up | Use per-test temp dirs and remove them in teardown |

## 5. Processes, ports, hangs

| Symptom | Likely cause | Action |
|---|---|---|
| `Address already in use` | Stale server | `lsof -ti:<port> | xargs -r kill`, wait 2 seconds, retry; use random free ports in tests |
| Command hangs, no output | Waiting for input or a foreground server | Kill it; rerun with `timeout`, non-interactive flags, `< /dev/null`; run servers in the background |
| Orphan processes after a failed run | No cleanup | Use `trap cleanup EXIT` in scripts; `pkill -f <name>` for processes you started |
| Background server dies silently | Crash or terminal closed | Use `nohup` or `tmux`; read the server log; add a watchdog |
| Zombie test runner holds a lock | Interrupted run | Remove stale lock files (only ones you can prove are stale), kill the process |
| Interactive installer prompts | Missing `-y` | Add `-y`, `--yes`, `--no-input`, `DEBIAN_FRONTEND=noninteractive`, `CI=1` |

## 6. Tests and the gate

| Symptom | Likely cause | Action |
|---|---|---|
| Flaky test (passes sometimes) | Randomness, timing, shared state | Seed RNGs, isolate state with temp dirs, replace sleeps with polling plus deadline; run 5 times before trusting; fix, do not skip |
| Test passes locally, fails in the gate | Different working directory, env var, ordering | Run it the way the gate does; use absolute paths from the repo root; reset env |
| Gate takes too long | Slow stages in quick mode | Move slow stages to full mode only; mark and cache expensive fixtures |
| Coverage below threshold | Untested code | Write tests for real behavior; never lower the threshold or exclude files just to pass |
| New failure after an unrelated change | Hidden coupling | Bisect: `git stash`, `git bisect`, or revert to the last good tag and reapply in smaller steps |
| Test expects values that depend on the date or network | Uncontrolled inputs | Freeze time, mock the network at the boundary, use fixtures |
| Fixtures missing | No sample data | Generate synthetic data in code, or use public-domain samples from standard libraries; log it |

## 7. Git

| Symptom | Likely cause | Action |
|---|---|---|
| `index.lock exists` | Interrupted git command | Check no git process runs (`pgrep git`), then `rm -f .git/index.lock` |
| Detached HEAD | Checked out a tag or commit | `git checkout -B main` (after stashing or committing) |
| Merge conflict markers in files | Earlier merge or stash pop | Resolve by choosing the intended version, remove markers, run the gate |
| Accidentally committed a secret | Missing gitignore | Remove it, rotate the secret conceptually (note in the report that the human must rotate it), rewrite only local unpushed history if safe, add to `.gitignore` |
| Huge files committed | Models or data in git | Add to `.gitignore`, `git rm --cached`, keep downloads reproducible via a script |
| Repository corrupted | Disk full or kill during write | `git fsck`; if unrecoverable, copy the working tree out, re-init, commit, and note it in the log |

## 8. Agent and tool friction

| Symptom | Likely cause | Action |
|---|---|---|
| Tool asks for permission or confirmation | Safety prompt | Approve if the action is inside the project and within the safety tier; otherwise do not do it and find another way |
| Edit tool says text not found or not unique | File changed or ambiguous match | Re-read the file, include more surrounding context, or rewrite the section |
| File too large to read | Output limit | Read in ranges; `grep -n` for the relevant part; summarize to `LOG.md` |
| You lose track of what you were doing | Context reset or overload | Run the Resuming procedure (SKILL.md section 12) |
| Output flooded with logs | Verbose commands | Redirect to `logs/*.log` and `tail -n 60` |
| Session ended mid-task | Turn or token limit | The outer driver restarts you; make sure your last action was a commit or a LOG entry so work resumes cleanly |
| Rate limit or overload error from the model API | Provider limits | Back off 30 to 120 seconds, reduce parallel subagents, continue; the driver pauses and retries |
| Repeated self-contradicting edits | Thrashing | Apply the thrash detector (SKILL.md 6.4) |

## 9. Databases and data

| Symptom | Likely cause | Action |
|---|---|---|
| Connection refused | DB not running | Start it in the background (or use SQLite or a container for tests) and poll for readiness |
| Migration fails | Order or state mismatch | Start from a clean test database; make migrations idempotent; test them in the gate |
| Tests pollute each other's data | Shared DB | Use a fresh DB or transaction rollback per test |
| `database is locked` (SQLite) | Concurrent writers | Use WAL mode, a single writer, or short transactions with a timeout |
| Data too big for memory | Loading everything | Stream or chunk; sample for tests |
| Destructive command on real data | Wrong target | Never run destructive commands against anything but test data; Tier 1 forbids touching external databases |

## 10. Web, frontend, browsers

| Symptom | Likely cause | Action |
|---|---|---|
| Headless browser fails to launch | Missing system libs or sandbox | `npx playwright install --with-deps chromium` (if sudo), or `--no-sandbox` for the headless test browser only |
| UI looks broken but tests pass | No visual check | Take screenshots at mobile and desktop widths into `debug/` and inspect them |
| CORS errors in tests | Origin mismatch | Configure the dev server or test against the same origin |
| Build works, runtime blank page | Console errors | Capture console output in the smoke test and fail on errors |
| CDN assets blocked | Egress limits | Vendor the asset locally |

## 11. Secrets, auth, permissions

| Symptom | Likely cause | Action |
|---|---|---|
| Missing API key | Not provided | Never invent keys. Use mock mode or a stub with a clear flag and test; list the needed key in the final report |
| 401 / 403 from a service | Wrong or absent credentials | Do not try other people's credentials; fall back to mock; log it |
| `Permission denied` on a file | Ownership or mode | `ls -l`; fix ownership or mode only inside the project; never `chmod 777` |
| Port below 1024 refused | Needs root | Use a high port (8000+) and note it |
| Secret printed in logs | Careless logging | Remove it from logs, add redaction, add a test that greps logs for key patterns |

## 12. Long-running and unattended specifics

| Symptom | Likely cause | Action |
|---|---|---|
| Agent stops after one task | It thinks the job is done | Strengthen `TASKS.md`, keep the gate honest, and rely on the outer driver to relaunch |
| Agent finishes early with "done" but gate is red | Premature success claim | Gate decides; keep going |
| Same error for hours | Stuck in a rut | 3-strike rule, then block and move on; the stop condition for three idle iterations protects the budget |
| Machine reboots overnight | Instance restart | On resume, section 12 of the skill; restart services via the watchdog or systemd |
| SSH session closed and the agent died | Process tied to the terminal | Run the driver in `tmux` or with `nohup` |
| Time or cost overrun | No cap | Budgets in `GOAL.md`; driver `MAX_HOURS`, `MAX_RUNS`; model-side spending caps where the CLI offers them |
| Clock skew or wrong date | Server clock | Use `date -Is` consistently; do not trust cached timestamps |

## 13. Quality problems (it works but is wrong)

| Symptom | Action |
|---|---|
| Output passes the gate but looks wrong | The gate is too weak. Add a validator or a visual check, then fix the product |
| Spec is ambiguous | Make the ambiguous value a named constant, document both readings in `DECISIONS.md`, pick one, and test the boundary |
| Fallback path silently used | Log loudly when a fallback is active and surface it in the health endpoint or the final report |
| Performance is poor | Measure first (profile or time), fix the biggest cost, re-measure, record numbers in `LOG.md` |
| Security smell (injection, path traversal, unsafe uploads) | Add a negative test, fix, keep the test |
