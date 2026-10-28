# Concerto workflow
- Non-trivial coding tasks (several files or several goals): the main session plans, delegates implementation to the `executor` (Sonnet) subagent and verifies with `verifier`. See the `/opus` skill for the full flow.
- Trivial changes (one file, under 30 lines) are done directly, without the pipeline.
- When the user says "note this down / later" → append to `.claude/work/ideas.md`.
- Prompts sent to subagents must be self-contained: they cannot see the conversation.
- Never push, force, or delete unmerged branches unless the user explicitly asks.
