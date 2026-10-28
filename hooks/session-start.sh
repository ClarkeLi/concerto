#!/usr/bin/env bash
# Concerto: remind about unfinished plans and pending ideas at session start.
# Any error exits silently; this must never slow down or break session start.
trap 'exit 0' ERR
input=$(cat 2>/dev/null)
dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
dir=${dir:-${CLAUDE_PROJECT_DIR:-$PWD}}
[ -d "$dir/.claude/work" ] || exit 0
out=""; n=0
for p in "$dir"/.claude/work/*/plan.md; do
  [ -f "$p" ] || continue
  st=$(grep -m1 '^- status:' "$p" | sed 's/^- status: *//; s/ .*//')
  id=$(basename "$(dirname "$p")")
  total=$(grep -c '^### T' "$p")
  done_n=$(awk '/^### T/{t=1} t&&/^- status: *done/{c++; t=0} END{print c+0}' "$p")
  [ "$st" = "done" ] && [ "$done_n" -ge "$total" ] && continue
  out="$out ${id}(${done_n}/${total})"
  n=$((n+1))
done
ideas=$(grep -c '^- \[ \]' "$dir/.claude/work/ideas.md" 2>/dev/null)
[ "${ideas:-0}" -gt 0 ] && echo "[concerto] ${ideas} idea(s) waiting in the pool; /opus with no arguments processes them all in parallel"
[ "$n" -gt 0 ] && echo "[concerto] ${n} unfinished plan(s):${out}. See /encore, resume with /da-capo"
exit 0
