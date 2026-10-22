# Autonomous Loop 🔁

> **Unattended, self-healing, test-gated execution loop for autonomous AI coding agents.**  
> Supports **Google Antigravity CLI (`agy`)**, **Claude Code**, **Cursor**, **Codex**, and any agent platform capable of reading Markdown protocols or skills.

---

## Table of Contents
- [Overview](#overview)
- [Repository & File Structure](#repository--file-structure)
- [Runtime State Architecture (`.loop/`)](#runtime-state-architecture-loop)
- [The 10 Prime Rules](#the-10-prime-rules)
- [The 9-Step Execution Cycle](#the-9-step-execution-cycle)
- [Anti-Stuck & Self-Repair Protocol](#anti-stuck--self-repair-protocol)
- [Safety Tiers & Guardrails](#safety-tiers--guardrails)
- [How to Use with Google Antigravity CLI (`agy`)](#how-to-use-with-google-antigravity-cli-agy)
  - [1. Skill Installation](#1-skill-installation)
  - [2. Scaffolding a Target Project](#2-scaffolding-a-target-project)
  - [3. Interactive CLI Mode](#3-interactive-cli-mode)
  - [4. Headless Single-Session Mode](#4-headless-single-session-mode)
  - [5. Overnight Autonomous Driver with Antigravity](#5-overnight-autonomous-driver-with-antigravity)
  - [6. Antigravity IDE / Desktop GUI Mode](#6-antigravity-ide--desktop-gui-mode)
- [How to Use with Claude Code](#how-to-use-with-claude-code)
- [Monitoring & Morning Handoff](#monitoring--morning-handoff)
- [License](#license)

---

## Overview

Most AI coding agents stall, hallucinate, drift, or burn tokens when left alone:
1. They stop and wait when they hit an ambiguous question or permission prompt.
2. They rely on their ephemeral LLM context window; once truncated or reset, they forget where they were and start over.
3. They declare "all tasks finished" based on their own subjective opinion rather than objective machine verification.
4. They fall into repetitive error loops (thrashing) when a tool or test fails.

**Autonomous Loop** solves this by establishing a rigorous protocol:
- **External Memory**: The source of truth is persisted entirely on disk in `.loop/` files (`GOAL.md`, `TASKS.md`, `LOG.md`, `ERRORS.md`, `DECISIONS.md`), never in model context.
- **The Verify Gate is the Judge**: Work is only "Done" when an objective executable test gate (`scripts/verify.sh`) exits `0`.
- **Zero-Human Intervention**: The agent is forbidden from pausing to ask questions. Decisions are recorded in `DECISIONS.md`.
- **Autonomous Outer Supervisor**: If a session crashes, times out, or hits a turn limit, `scripts/loop_driver.sh` automatically resumes the work in a clean session.

---

## Repository & File Structure

```
autonomous-loop/
├── SKILL.md                          # Primary agent skill protocol specification
├── README.md                         # Comprehensive documentation & Antigravity CLI usage
├── scripts/
│   ├── init_loop.sh                  # Project scaffold script (initializes .loop/ directory)
│   ├── loop_driver.sh                # Resilient multi-session outer supervisor loop
│   └── status.sh                     # Single-screen dashboard & health check script
└── references/
    ├── failure-playbook.md           # Diagnostic playbook for environment and process failures
    ├── state-templates.md            # Exact markdown schemas for all .loop/ state files
    ├── unattended-setup.md           # VPS provisioning, headless permission setup & morning checklist
    └── verify-patterns.md            # Recipes for non-gameable verify gates across stacks
```

### Detailed Breakdown of Components

| Component | Path | Description |
|---|---|---|
| **Core Protocol** | `SKILL.md` | The universal instruction manual for the agent. Contains the 10 Prime Rules, 9-step execution cycle, anti-stuck ladder, safety tiers, and stop budgets. |
| **Scaffolding Tool** | `scripts/init_loop.sh` | Sets up a target project repository with the `.loop/` folder, templates, starter task queue, and a failing `scripts/verify.sh` template. |
| **Outer Supervisor** | `scripts/loop_driver.sh` | A POSIX bash supervisor that manages multi-session agent execution. Features file locking (`flock`), progress fingerprinting, automated backoff, timeout enforcement, and circuit breaking. |
| **Health Dashboard** | `scripts/status.sh` | Displays a real-time status summary: heartbeat freshness, task counts (done/todo/blocked), recent commits, driver logs, and final report status. |
| **State Templates** | `references/state-templates.md` | Standard markdown templates for `GOAL.md`, `TASKS.md`, `LOG.md`, `STATUS.md`, `DECISIONS.md`, `ERRORS.md`, and `FINAL_REPORT.md`. |
| **Failure Playbook** | `references/failure-playbook.md` | Actionable fixes for common overnight crashes: zombie ports, out-of-memory, swap exhaustion, package lock errors, and timeout hangs. |
| **Unattended Setup** | `references/unattended-setup.md` | Step-by-step instructions for preparing isolated cloud environments, permissions, and security. |
| **Verify Patterns** | `references/verify-patterns.md` | Verification gate blueprints for Python, Node.js, Go, Rust, Ruby, Docker, and non-code deliverables. |

---

## Runtime State Architecture (`.loop/`)

When activated in a project, the agent creates and maintains a `.loop/` directory:

```
<project-root>/
├── .loop/
│   ├── GOAL.md                       # High-level objective, acceptance criteria, budgets & safety tier
│   ├── TASKS.md                      # Ordered checklist: [ ] todo, [x] done, [!] blocked
│   ├── STATE                         # Single line: RUNNING, FINISHED, or STOPPED <reason>
│   ├── STATUS.md                     # Heartbeat updated every iteration (timestamp, task, failures)
│   ├── LOG.md                        # Append-only iteration log (under 10 lines per iteration)
│   ├── DECISIONS.md                  # Autonomous judgment calls & test modifications log
│   ├── ERRORS.md                     # Error fingerprints and resolution history
│   ├── PROMPT.md                     # Resume prompt used by the outer driver
│   ├── PROTOCOL.md                   # Static copy of SKILL.md for agents lacking skill engines
│   └── FINAL_REPORT.md               # Post-run handoff summary produced upon completion
└── scripts/
    └── verify.sh                     # Objective, machine-checkable verification gate (exit 0)
```

---

## The 10 Prime Rules

1. **Never ask the human a question and wait**: Make the most reasonable decision, log it in `DECISIONS.md`, and keep moving.
2. **The gate is the judge**: "Done" means `scripts/verify.sh` exits `0` and all criteria in `GOAL.md` are satisfied.
3. **Never move the goalposts**: Never delete tests, weaken assertions, or edit thresholds to pass artificially. If a test is defective, run a Meta-Verification Audit and log the exact diff and reason in `DECISIONS.md`.
4. **Never block the terminal**: Every command that can hang must use `timeout`. Background long-running processes. Pass `-y`, `--yes`, `DEBIAN_FRONTEND=noninteractive`.
5. **Stay inside the project**: Never touch `~/.ssh`, cloud credentials, system configurations, or parent directories.
6. **Spend zero money without explicit permission**: Paid APIs, cloud deployments, and production push require Tier 2 or Tier 3 permissions in `GOAL.md`.
7. **No secrets in git or logs**: Always utilize gitignored `.env` with fake template values in `.env.example`.
8. **Commit small and often**: Every finished task gets an atomic commit. The repository must always be rollback-ready.
9. **Do not loop forever**: Strictly enforce wall-clock, iteration, and attempt budgets.
10. **Be honest**: A clear "PARTIAL: here is what failed" report is infinitely better than a fake "SUCCESS".

---

## The 9-Step Execution Cycle

Every single iteration follows a disciplined state-machine:

```mermaid
flowchart TD
    A[1. ORIENT: Read .loop state & git status] --> B[2. HEALTH: Check verify.sh quick mode]
    B -->|Gate Broken| B1[Fix or Revert to Last Good Tag]
    B1 --> A
    B -->|Gate Healthy| C[3. CHOOSE: Next task from TASKS.md]
    C --> D[4. PLAN: 3-6 line plan in LOG.md]
    D --> E[5. TEST: Write test / check first - Red]
    E --> F[6. BUILD: Minimal code change - Green]
    F --> G1[7. REFACTOR: Lint, types & clean code - Refactor]
    G1 --> G[8. VERIFY: Run checks & scripts/verify.sh]
    G -->|Pass| H1[9a. PASS: Commit, mark [x], reset error count]
    G -->|Fail| H2[9b. FAIL: Anti-Stuck Ladder & Meta-Verification]
    H1 --> I{All Tasks Done?}
    H2 --> C
    I -->|No| A
    I -->|Yes| J[10. FULL GATE: Run full 3-stage verify.sh]
    J -->|Pass| K[11. FINISHING: Write FINAL_REPORT.md, STATE=FINISHED]
    J -->|Fail| L[Add fix tasks to TASKS.md]
    L --> A
```

---

## Anti-Stuck & Self-Repair Protocol

When a command or test fails, the agent generates an **error fingerprint** (normalized exception type and core message) and logs it into `.loop/ERRORS.md`:

```
| Fingerprint | Count | What Was Tried | What Fixed It |
|---|---|---|---|
| ModuleNotFoundError: httpx | 1 | poetry add httpx | Installed dependency in venv |
```

### The Strategy Ladder:
1. **Attempt 1**: Apply the direct, most likely fix.
2. **Attempt 2**: Deep diagnosis (reproduce in minimal isolated test, inspect full stacktrace, verify versions).
3. **Attempt 3 (Three-Strike Rule & Meta-Verification Audit)**:
   - Pause application code changes.
   - Run a **Meta-Verification Audit**: inspect `scripts/verify.sh` and the failing test for flawed mock signatures, impossible assertions, or environment bugs.
   - If test is flawed, fix test and log diff in `DECISIONS.md`.
   - If test is valid, pivot strategy completely using alternative pattern or library.
4. **Attempt 4 (Block & Move On)**:
   - If still failing, mark task `- [!] BLOCKED <reason>` in `TASKS.md`, commit, and immediately proceed to the next task to prevent token and budget burn. Revisit only at the end if budget remains.

---

## Safety Tiers & Guardrails

| Tier | Name | Allowed Capabilities | Hard Restrictions |
|:---:|:---|:---|:---|
| **Tier 1** *(Default)* | **Sandbox** | Read/write in project directory, local virtualenvs, local test servers, local git commits. | No network writes, no remote pushes, no paid APIs, no cloud modifications. |
| **Tier 2** | **Project + Network** | Tier 1 + downloading models/packages, free external APIs, git push to non-main branches. | No production deploys, no destructive remote actions, no paid cloud spend. |
| **Tier 3** | **Deploy** | Tier 2 + deployment to explicitly designated staging/prod environments with rollback plan. | Actions not explicitly pre-approved in `GOAL.md`. |

---

## How to Use with Google Antigravity CLI (`agy`)

Google Antigravity CLI (`agy`) is designed for AI-first agentic coding. `autonomous-loop` integrates natively with `agy` using both interactive and headless supervisor workflows.

### 1. Skill Installation

Install `autonomous-loop` globally for all projects:

```bash
# Antigravity standard skill location
mkdir -p ~/.agents/skills
cp -r /path/to/autonomous-loop ~/.agents/skills/autonomous-loop
```

Or install it locally inside a specific project:

```bash
cd ~/your-project
mkdir -p .agents/skills
cp -r /path/to/autonomous-loop .agents/skills/autonomous-loop
```

Add a pointer to your workspace rules (`AGENTS.md` or `GEMINI.md`):

```markdown
# Autonomous Work Rules
For autonomous, overnight, or multi-step work, activate and strictly follow the `autonomous-loop` skill and `.loop/PROTOCOL.md`.
```

---

### 2. Scaffolding a Target Project

Run the initialization script inside your target project directory:

```bash
cd ~/your-project
bash ~/.agents/skills/autonomous-loop/scripts/init_loop.sh .
```

This creates:
- `.loop/` populated with state files and templates.
- `scripts/verify.sh` configured as an objective check (fails by default until configured).

Edit `.loop/GOAL.md` to define your acceptance criteria, or supply a `PRD.md`.

---

### 3. Interactive CLI Mode

If you are using the Antigravity CLI interactively, start an `agy` session and prompt the agent:

```bash
agy -i "Use the autonomous-loop skill. Build what is described in PRD.md until scripts/verify.sh passes. Follow all rules in .loop/PROTOCOL.md."
```

---

### 4. Headless Single-Session Mode

To run `agy` non-interactively without human permission prompts:

```bash
cd ~/your-project

agy -p "$(cat .loop/PROMPT.md)" \
    --dangerously-skip-permissions \
    --mode auto \
    --model gemini-3.8-flash \
    --effort high
```

Key `agy` flags used:
- `-p` / `--print`: Executes the prompt non-interactively and streams the response.
- `--dangerously-skip-permissions`: Automatically approves terminal execution and file edits without stalling on prompts.
- `--mode auto`: Grants the agent full autonomous editing and tool execution capabilities.
- `--model`: Specifies the model (e.g., `gemini-3.8-flash` or `gemini-3.8-pro`).
- `--effort high`: Sets reasoning depth for complex architectural and debugging tasks.

---

### 5. Overnight Autonomous Driver with Antigravity

For true overnight, all-night unattended runs, use `scripts/loop_driver.sh`. If an `agy` session finishes, crashes, or hits context/timeout limits, the driver automatically spins up a fresh session that resumes from disk state:

```bash
cd ~/your-project

# Configure the driver to use Antigravity CLI
export AGENT_TYPE=agy
export I_UNDERSTAND_SANDBOX=1
export MAX_HOURS=8
export MAX_RUNS=30
export PAUSE=15

# Launch inside a persistent tmux session
tmux new -s agy-loop
bash ~/.agents/skills/autonomous-loop/scripts/loop_driver.sh
```

Detach from `tmux` via `Ctrl+B` then `D`. Reattach at any time with:
```bash
tmux attach -t agy-loop
```

#### Custom Antigravity Driver Command
You can also pass explicit parameters via `AGENT_CMD`:

```bash
export AGENT_CMD='agy -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --mode auto --effort high'
bash ~/.agents/skills/autonomous-loop/scripts/loop_driver.sh
```

---

### 6. Antigravity IDE / Desktop GUI Mode

When working inside the Antigravity Desktop IDE:
1. Open your project folder containing `.loop/`.
2. Configure **Terminal Command Auto Execution** to "Always Proceed / Turbo" in Settings.
3. In the chat input, paste the kickoff prompt:

```text
Use the autonomous-loop skill.
Follow .loop/GOAL.md and .loop/TASKS.md.
I am away and cannot answer questions.
Run the loop until scripts/verify.sh passes or a stop condition is met.
Update .loop/STATUS.md each iteration and generate .loop/FINAL_REPORT.md when complete.
```

---

## How to Use with Claude Code

The autonomous loop works out-of-the-box with `claude`:

```bash
# Global install for Claude Code
mkdir -p ~/.claude/skills
cp -r /path/to/autonomous-loop ~/.claude/skills/autonomous-loop

# Launch with driver on a disposable machine
cd ~/your-project
export I_UNDERSTAND_SANDBOX=1
export MAX_HOURS=2
export MAX_RUNS=10
export MAX_BUDGET_USD=5.00
bash ~/.claude/skills/autonomous-loop/scripts/loop_driver.sh
```

---

## Monitoring & Morning Handoff

### Real-Time Inspection

Check loop health at any time without disturbing the agent:

```bash
bash scripts/status.sh ~/your-project
```

Example output:
```
== STATE ==
RUNNING

== STATUS ==
# Status
- updated: 2026-10-22T04:15:32+00:00
- iteration: 14
- current task: T06 Implement database migration
- last gate result: PASS
- consecutive failures on this task: 0
heartbeat age: 24s

== TASKS ==
done=6 todo=3 blocked=1
- [!] T04 Redis pubsub fallback implemented via memory bus

== GIT ==
d4f910a T06: Add PostgreSQL migration schema
1b302ef T05: User authentication integration tests
...
```

### The Morning Routine

When you wake up or return:
1. **Check Status**: `bash scripts/status.sh .`
2. **Read Final Report**: Open `.loop/FINAL_REPORT.md` (contains verification evidence, built components, and next steps).
3. **Inspect Decisions**: Read `.loop/DECISIONS.md` to review autonomous judgment calls.
4. **Run Verification**: Manually execute `bash scripts/verify.sh`.
5. **Inspect Artifacts**: Check generated files, test logs, and `debug/` screenshots.

---

## License

MIT License. Designed for reliable, high-agency autonomous agent engineering.
