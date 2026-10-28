# <plan title>
- id: <plan-id>
- created: <ISO time>
- base_branch: <original branch>
- base_sha: <base commit>
- integration_branch: concerto/<plan-id>
- status: planning | running | merging | done | partial | failed
- test_cmd: <full test command, e.g. `npm test` / `pytest -q`; `none` if there are no tests>
- round: <k>/3
- ideas: [<exact lines taken from .claude/work/ideas.md for this plan>]

## Goal
<the user's words + one or two sentences of clarified understanding>

## Tasks

### T1 · <title>
- status: todo        # todo | running | verifying | done | failed | blocked
- size: S             # S(<30 lines) | M | L
- deps: []
- wave: 1
- files: [src/a.ts, tests/a.test.ts]
- goal: <one sentence>
- steps:
  1. ...
- acceptance:
  - ...
- verify: `<command>`
- attempts: 0
- branch:
- result:

## Waves
- wave 1: T1, T2 (parallel)
- wave 2: T3 (depends on T1)

## Risks / assumptions
- ...
