#!/usr/bin/env bash
# Removes what install.sh added. Backups (*.bak-concerto) and project data
# (.claude/work/) are left untouched.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
DEST=${CLAUDE_HOME:-$HOME/.claude}
HOOK="$DEST/concerto/hooks/session-start.sh"
BEGIN='<!-- concerto:begin -->'
END='<!-- concerto:end -->'

for f in "$SRC"/agents/*.md; do rm -f "$DEST/agents/$(basename "$f")"; done
for d in "$SRC"/skills/*/;   do rm -f "$DEST/skills/$(basename "$d")/SKILL.md"; rmdir "$DEST/skills/$(basename "$d")" 2>/dev/null || true; done
rm -rf "$DEST/concerto"

MD="$DEST/CLAUDE.md"
if [ -f "$MD" ] && grep -qF "$BEGIN" "$MD"; then
  awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$MD" \
    | awk '{l[NR]=$0} END{n=NR; while(n>0&&l[n]=="")n--; for(i=1;i<=n;i++)print l[i]}' > "$MD.tmp" && mv "$MD.tmp" "$MD"
  [ -s "$MD" ] || rm -f "$MD"
fi

SET="$DEST/settings.json"
if [ -f "$SET" ]; then
  jq --arg cmd "\"$HOOK\"" '
    if .hooks.SessionStart then
      .hooks.SessionStart |= map(.hooks |= map(select(.command != $cmd))) | .hooks.SessionStart |= map(select(.hooks | length > 0))
    else . end' "$SET" > "$SET.tmp" && jq empty "$SET.tmp" && mv "$SET.tmp" "$SET"
fi
echo "Concerto removed from $DEST"
