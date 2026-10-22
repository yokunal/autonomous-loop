#!/usr/bin/env bash
# One-screen summary of a loop run. Usage: bash status.sh [project_dir]
DIR="${1:-.}"
cd "$DIR" 2>/dev/null || { echo "no such dir: $DIR"; exit 1; }
[ -d .loop ] || { echo "no .loop/ in $PWD"; exit 1; }

echo "== STATE =="; cat .loop/STATE 2>/dev/null
echo
echo "== STATUS =="; cat .loop/STATUS.md 2>/dev/null
if [ -f .loop/STATUS.md ]; then
  upd=$(grep -m1 'updated:' .loop/STATUS.md | sed 's/.*updated: *//')
  if [ -n "$upd" ] && ts=$(date -d "$upd" +%s 2>/dev/null); then
    age=$(( $(date +%s) - ts ))
    echo "heartbeat age: ${age}s $( [ "$age" -gt 1800 ] && echo '(STALE: agent may be stuck or stopped)' )"
  fi
fi
echo
echo "== TASKS =="
done_n=$(grep -c '^- \[x\]' .loop/TASKS.md 2>/dev/null); todo_n=$(grep -c '^- \[ \]' .loop/TASKS.md 2>/dev/null); blk_n=$(grep -c '^- \[!\]' .loop/TASKS.md 2>/dev/null)
echo "done=$done_n todo=$todo_n blocked=$blk_n"
grep -E '^- \[!\]' .loop/TASKS.md 2>/dev/null
echo
echo "== LAST LOG =="; tail -n 20 .loop/LOG.md 2>/dev/null
echo
echo "== GIT =="; git log --oneline -8 2>/dev/null; git status --short 2>/dev/null | head -10
echo
echo "== DRIVER =="; tail -n 8 .loop/driver.log 2>/dev/null
echo
[ -f .loop/FINAL_REPORT.md ] && echo "Final report: $PWD/.loop/FINAL_REPORT.md" || echo "No final report yet."
