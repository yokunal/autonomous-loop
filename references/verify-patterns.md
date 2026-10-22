# Building the verify gate

The loop is only as good as its gate. This file shows how to make `scripts/verify.sh` objective, layered, and hard to game, for any stack.

## Contents
- Gate skeleton (bash)
- Per-stack recipes
- Testing running services
- Validators for generated artifacts
- Negative and property tests
- Non-code goals (docs, data, research, design, infra)
- Making the gate hard to cheat
- Common mistakes

---

## Gate skeleton

```bash
#!/usr/bin/env bash
# scripts/verify.sh [--quick]
set -euo pipefail
QUICK=0; [ "${1:-}" = "--quick" ] && QUICK=1
cd "$(dirname "$0")/.."
fail() { echo "VERIFY FAILED at stage: $1"; exit 1; }

echo "== lint ==";  timeout 300 <lint command> || fail lint
echo "== unit ==";  timeout 900 <unit test command> || fail unit
if [ "$QUICK" = 0 ]; then
  echo "== integration =="; timeout 900 <integration command> || fail integration
  echo "== live smoke ==";  bash scripts/smoke.sh || fail smoke
  echo "== secrets ==";     bash scripts/secret_scan.sh || fail secrets
fi
echo "VERIFY OK"
```

Rules:
- Every stage under `timeout`.
- Exit code 0 only if every stage passed. Last line is `VERIFY OK` on success.
- If the project is not configured yet (no tests, no command), the gate **fails** with `NOT CONFIGURED`. A gate that passes on an empty project is worse than no gate.
- Quick mode must finish in under about 2 minutes so every iteration can run it.

## Per-stack recipes

| Stack | Lint | Tests | Build / type check |
|---|---|---|---|
| Python | `ruff check .` (or `flake8`) | `pytest -q --cov=<pkg> --cov-fail-under=<n>` | `mypy <pkg>` if typed |
| Node / TS | `npx eslint .` | `npm test` (jest, vitest) | `npx tsc --noEmit`, `npm run build` |
| Go | `go vet ./...`, `gofmt -l .` must be empty | `go test ./... -race -count=1` | `go build ./...` |
| Rust | `cargo clippy -- -D warnings` | `cargo test` | `cargo build --release` |
| Java / Kotlin | checkstyle or ktlint | `./gradlew test` or `mvn -q test` | `./gradlew build` |
| PHP | `phpcs` | `phpunit` | `composer validate` |
| Static site | link and HTML check (`htmlproofer`, `linkinator`) | Playwright or simple `curl` checks | `npm run build` |
| Mobile (Flutter) | `flutter analyze` | `flutter test` | `flutter build apk --debug` |
| Infra (Terraform / Docker) | `terraform validate`, `hadolint` | `terraform plan` (no apply), `docker build` | `docker run` smoke |
| Shell tooling | `shellcheck` | `bats` | n/a |

Pin dependency versions once a working set exists (`pip freeze > requirements.txt`, lockfiles committed).

## Testing running services

A passing unit suite does not prove the service works. Add a live smoke script:

1. Pick a free port (bind to 0 or choose randomly) and start the server in the background with a log file.
2. Poll the health endpoint with a deadline (for example up to 90 seconds, because models or caches may load slowly). Fail with the log tail if it never comes up.
3. Run the real flow over real HTTP (create, read, update, delete, auth, payment in mock mode, file upload and download, whatever the product does).
4. Run a small concurrency test (for example 5 parallel requests) and check for crashes.
5. Record response times; assert a sane upper bound.
6. Stop the server in a `trap` so it is killed even when a step fails.

```bash
cleanup() { [ -n "${PID:-}" ] && kill "$PID" 2>/dev/null || true; }
trap cleanup EXIT
```

## Validators for generated artifacts

If the product produces files (images, PDFs, reports, exports), write a validator that **re-opens the produced file and measures it** against the spec, then use it in tests and, where cheap, at runtime before delivery.

Examples: image width, height, format, file size range, background colour at the borders; PDF page count and text present; CSV has the expected columns and no empty required fields; JSON validates against a schema; generated code compiles; a document contains every required section heading.

Validators prevent the classic failure where the code "worked" but the output is subtly wrong.

## Negative and property tests

For every input type, test what should be rejected and that the error is clear: empty input, wrong type, too large, malformed, hostile (path traversal, huge numbers, unicode oddities). For anything with a numeric target, use a **property test** over many random inputs ("for 50 random inputs the output is always inside the allowed range or a clear error is returned").

## Non-code goals

When the goal is not "software that passes tests", convert it into mechanical checks:

| Goal type | How to make it checkable |
|---|---|
| Documentation / report | Required headings present; every item in a checklist appears; word count within a range; all links resolve; code samples execute; no `TODO` or `lorem` left; spell check passes |
| Data pipeline / ETL | Row counts match source within tolerance; schema and types validated; no nulls in required columns; checksums or sample records match expected values; pipeline is idempotent (run twice, same result) |
| Research / comparison | A fixed rubric file with required fields per item, each filled; every claim has a source URL; a script checks that URLs resolve and fields are non-empty |
| Migration / refactor | Old test suite passes unchanged; behavior snapshot tests (golden files) match; no references to removed APIs (`grep` count is 0) |
| Design / UI | Build succeeds; Playwright screenshot exists for each page at mobile and desktop widths; no console errors; basic accessibility check (axe) passes; the agent inspects the screenshots and notes findings in `LOG.md` |
| Infra / deployment | Config validates; health check URL returns 200 from outside the process; rollback command tested; idempotent re-run |
| Bug backlog | Each bug gets a failing test first, then the fix, then the test passes; the backlog file lists each bug with its test name |

If a criterion truly cannot be automated, define the **artifact** the agent must produce as evidence (a screenshot, a log excerpt, a diff summary) and make the gate check the artifact exists and is non-trivial. Put the remaining judgment in the final report, not in the gate.

## Making the gate hard to cheat

- Make `scripts/verify.sh` and the tests directory read as immutable in `GOAL.md`. Changes are only allowed through rule 3 of the skill, with a `DECISIONS.md` entry.
- Include a **canary**: a test that must fail when a known-bad input is fed in, so a gate that always passes is detected.
- Count tests. Require a minimum count so deleting tests fails the gate (`pytest --collect-only -q | tail -1`).
- Require a coverage floor on the application package, not on the tests.
- Scan for skip markers: fail if the number of `skip`, `xfail`, `.only`, or `@Ignore` increased (`grep -rE` count compared with a recorded baseline in `.loop/baseline.txt`).
- Run flaky tests several times before trusting them. Fix flakiness; do not retry-until-green in the gate.

## Common mistakes

- Gate that passes when nothing is configured.
- Only unit tests, no real end-to-end run.
- Health check that only checks the port is open, not that the app works.
- Using fixed `sleep` instead of polling with a deadline.
- Tests that depend on the network or on today's date without control.
- Running the full gate every iteration (too slow); use quick mode inside the loop and full mode before finishing.
- Tests that write into the real data directory instead of a temp directory.
