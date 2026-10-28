---
name: hum
description: Capture an idea into the project's idea pool in one line, or tidy the pending ideas. /hum <text> records; /hum with no arguments groups the pending ideas.
argument-hint: "[idea text]"
model: haiku
effort: low
allowed-tools: Bash
---

Arguments: $ARGUMENTS

File: `.claude/work/ideas.md`

## With arguments: record
Make exactly one Bash call (do not read files first, do not analyse):
`mkdir -p .claude/work && echo "- [ ] $(date +%F) <argument text verbatim>" >> .claude/work/ideas.md && grep -c '^- \[ \]' .claude/work/ideas.md`
Then reply only: "Recorded (N pending)." in the user's language.

## No arguments: tidy
1. Read only the `- [ ]` lines of ideas.md.
2. One line per group: `numbers idea…` → `/opus ideaA; ideaB`. Merge ideas that can be done together; the rest get a line each.
3. Add a final line: "Run everything at once: `/opus` (no arguments, groups and parallelises automatically)."
4. No explanations; do not modify the file.
