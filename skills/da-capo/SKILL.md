---
name: da-capo
description: Execute or resume an existing Concerto plan (after an interruption, or after hand-editing plan.md). Use when the user types /da-capo [plan-id].
argument-hint: "[plan-id]"
---

You are the orchestrator (Opus). Arguments: $ARGUMENTS

## Pick the plan
- A plan-id was given → use `.claude/work/<plan-id>/plan.md`.
- Omitted → pick the most recent plan under `.claude/work/` whose `status` is not `done`. If there is none, tell the user and stop.

## Restore state
1. Read plan.md. Skip `done` cards.
2. For `running` / `verifying` cards: check whether the matching branch (or a worktree from `git worktree list`) already has a `concerto(<task-id>)` commit. If yes → go straight to verification (dispatch a verifier); if no → reset the card to `todo`.
3. Make sure the integration branch `concerto/<plan-id>` exists; if not, create it from `base_sha`.
4. Append a line to log.md noting this resume.

## Execute
Read "Phase 3: Dependency-driven parallel scheduling" and "Phase 4: Wrap-up" in `~/.claude/skills/opus/SKILL.md` and follow them exactly. All other rules (never push, never force, do not interrupt the user unless a "Must ask" case occurs) still apply.
