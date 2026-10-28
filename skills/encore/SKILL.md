---
name: encore
description: Dashboard: shows the progress of every Concerto plan in the current project and the pending ideas. Read-only. Use when the user types /encore.
model: haiku
effort: low
allowed-tools: Bash
---

Read-only. Gather everything with one Bash call; do not read files one by one:
`for p in .claude/work/*/plan.md; do [ -f "$p" ] && echo "$(basename $(dirname $p)) $(grep -m1 '^- status' $p) $(awk '/^### T/{t=1;n++} t&&/^- status: *done/{d++} END{print d+0"/"n+0}' $p) $(awk '/^### T/{id=$2} /^- status: *(failed|blocked)/{printf "%s ",id}' $p)"; done; echo "ideas: $(grep -c '^- \[ \]' .claude/work/ideas.md 2>/dev/null)"`

Output (at most 6 lines, in the user's language; if there are no plans say so):
- One line per plan: `id · status · progress · failed/blocked cards`
- Last line: number of pending ideas plus one suggestion (unfinished plan → `/da-capo <id>`; ideas pending → `/opus` or `/hum`).
