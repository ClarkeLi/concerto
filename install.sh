#!/usr/bin/env bash
# Concerto installer. Copies agents, skills, hook and templates into ~/.claude
# (override with CLAUDE_HOME). Safe to re-run; existing differing files are
# backed up with the suffix .bak-concerto (only once, so re-runs keep the
# original), settings.json is never overwritten (one hook entry is appended
# after a backup).
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
DEST=${CLAUDE_HOME:-$HOME/.claude}
HOOK="$DEST/concerto/hooks/session-start.sh"
BEGIN='<!-- concerto:begin -->'
END='<!-- concerto:end -->'

for tool in git jq; do
  command -v "$tool" >/dev/null || { echo "error: '$tool' is required but not installed" >&2; exit 1; }
done

put() { # put <src> <dest>: copy, backing up a differing existing file (the first backup is kept)
  mkdir -p "$(dirname "$2")"
  if [ -f "$2" ] && ! cmp -s "$1" "$2" && [ ! -e "$2.bak-concerto" ]; then cp "$2" "$2.bak-concerto"; echo "  backed up $2"; fi
  cp "$1" "$2"
}

echo "Installing Concerto into $DEST"
for f in "$SRC"/agents/*.md;      do put "$f" "$DEST/agents/$(basename "$f")"; done
for d in "$SRC"/skills/*/;        do n=$(basename "$d"); put "$d/SKILL.md" "$DEST/skills/$n/SKILL.md"; done
put "$SRC/templates/plan.md"       "$DEST/concerto/templates/plan.md"
put "$SRC/hooks/session-start.sh"  "$HOOK"
chmod +x "$HOOK"

# CLAUDE.md: managed block between markers (replaced on re-install)
MD="$DEST/CLAUDE.md"; touch "$MD"
if grep -qF "$BEGIN" "$MD"; then
  awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$MD" > "$MD.tmp" && mv "$MD.tmp" "$MD"
fi
{ [ -s "$MD" ] && echo; echo "$BEGIN"; cat "$SRC/CLAUDE.snippet.md"; echo "$END"; } >> "$MD"

# settings.json: append the SessionStart hook once
SET="$DEST/settings.json"
[ -f "$SET" ] || echo '{}' > "$SET"
jq empty "$SET" 2>/dev/null || { echo "error: $SET is not valid JSON; aborting before touching it" >&2; exit 1; }
cp -n "$SET" "$SET.bak-concerto" || true
CMD="\"$HOOK\""
jq --arg cmd "$CMD" '
  .hooks.SessionStart = (.hooks.SessionStart // [])
  | if any(.hooks.SessionStart[]?.hooks[]?; .command == $cmd) then .
    else .hooks.SessionStart += [{"hooks":[{"type":"command","command":$cmd,"timeout":5}]}] end
' "$SET" > "$SET.tmp"
jq empty "$SET.tmp" && mv "$SET.tmp" "$SET"

echo "Done. Start a new Claude Code session, then try:  /hum your first idea   and   /opus"
