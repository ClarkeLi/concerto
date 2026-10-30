---
name: opus
description: Fully automatic coding workflow. Splits one or more ideas into task cards, dispatches them in parallel to Sonnet executors in isolated git worktrees, verifies them (light check by Opus for small cards, batched independent verifier for the rest), merges, and automatically continues with new ideas (up to 3 rounds). Use when the user types /opus <requirements>, or /opus with no arguments to process the whole idea pool.
argument-hint: "[requirement 1; requirement 2; ...] (empty = process the idea pool)"
---

You are the orchestrator (Opus). The user's requirements: $ARGUMENTS

**No-argument mode (idea-pool batch)**: if the requirements above are empty, take every `- [ ]` line in `.claude/work/ideas.md` as this round's requirements. If there are none, reply only "The idea pool is empty." and stop. Merge related ideas into one card; put independent ideas in the same wave so they run in parallel. Ideas too vague to decide on stay in the pool untouched; name them in one line in the final report. Record exactly which lines you took in the plan's `ideas:` field.

The user wants maximum automation: **do not ask for confirmation and do not stop to say "shall I continue?" unless one of the "Must ask" cases below occurs. Run everything to the end.**

Reply to the user in the language they use.

## Phase 0: Triage
- Requirements touch a single file and change under 30 lines → just do it yourself, skip the pipeline, report in one sentence.
- Several unrelated requirements that belong to different repositories → handle only the current repository; append the rest to `.claude/work/ideas.md` and tell the user.

## Phase 1: Prepare the repository
plan-id format: `YYYYMMDD-HHMM-short-slug`.
1. Not a git repository: make sure the current directory is neither `$HOME` nor `/`, then `git init`, write a sensible `.gitignore`, and make an initial commit `concerto: initial snapshot`.
2. Uncommitted changes in the working tree: `git stash push -u -m "concerto-autostash-<plan-id>"` and note it in the log (restored at the end).
3. Append `.claude/work/` to `.git/info/exclude` (skip if already present).
4. Record `base_branch` and `base_sha`, then create the integration branch `concerto/<plan-id>` (do not switch to it yet).

## Phase 2: Recon and planning
1. Recon first: directory layout, README, package files, test command, relevant modules. For large scope use Explore agents in parallel.
2. Write `.claude/work/<plan-id>/plan.md` from the template at `~/.claude/concerto/templates/plan.md` (and create an empty `log.md`). Splitting rules:
   - Each card is a unit a Sonnet can finish **independently and verify on its own**, ideally 1–5 files and under 200 lines.
   - `size` decides how the card is verified, so be honest: `S` only when the change is under 30 lines **and** has no tricky logic (concurrency, security, data migration, public API, parsing edge cases); anything else is `M` or `L`, however small.
   - `steps` must be concrete down to function or interface level. Leave no "decide for yourself" gaps that need design judgement; make the design decisions here.
   - `acceptance` must be objectively checkable; `verify` must be a runnable command (if there is no test framework, use a command or script that proves the feature works). Scope `verify` to the card (e.g. `pytest -q tests/test_x.py`), not the whole suite; the full `test_cmd` runs after every merge anyway. Prefer quiet flags so its output stays short.
   - **Bundle small cards**: related `S` cards in the same wave whose combined change stays under 200 lines become one card (size `M`, so it goes through the verifier). Each agent start costs a lot of tokens; unrelated small cards stay separate so they still run in parallel.
   - **Cards in the same wave must not share `files`**; if they do, move them to different waves.
   - Shared interfaces or types become a small wave-1 card that later cards depend on.
3. Sanity-check the plan: dependency graph has no cycles, every card has a verify command, the waves make sense.

### Must ask the user (only these cases)
- The requirement has two or more readings and a wrong guess is costly (deletes data, changes a public API, irreversible migration).
- It needs a secret, an account or a paid resource from the user.
- It fundamentally conflicts with the existing architecture.

## Phase 3: Dependency-driven parallel scheduling
Goal: finish as fast as possible with no idle slots. Do not "finish a whole wave, then start the next"; **start a card the moment its dependencies are satisfied**.

Scheduling loop (until every card is done/failed/blocked):
1. **Dispatchable**: status `todo`, all `deps` are `done` and merged into the integration branch, and `files` do not overlap any `running`/`verifying` card. Dispatch all such cards **in a single message, in parallel**, as executors: `subagent_type: "executor"`, `isolation: "worktree"`, `run_in_background: true`; for size `S` cards on their first attempt add `model: "haiku"` (M/L and every retry use the executor's default Sonnet). At most 4 concurrent agents (executors + verifiers); queue the rest, critical path (longest dependency chain) first.
2. The dispatch prompt must be **self-contained** (the executor cannot see this conversation), but **do not copy the card into it**: give the task id and the absolute path of plan.md so the executor reads the card itself, plus two or three sentences of project background, code conventions not obvious from the code, the base commit, and the requirement to return the executor report format (including the output of `pwd` and `git branch --show-current`). Your output tokens are the most expensive in the pipeline; keep dispatch prompts short.
3. **Worktree base**: a subagent worktree is based on the default branch by default, which may not contain what has already been merged. The prompt must tell the executor to run **`git merge concerto/<plan-id>` before starting**.
4. **Pipelined, tiered verification**: handle every executor the moment it returns; do not wait for the rest of its batch.
   - `DONE`, size `S`, first attempt → **light check by you, no verifier**: `git -C <worktree> diff <base>..HEAD` (the diff is under 30 lines, read it all), confirm only the card's `files` changed and every acceptance criterion is visibly met, and run the card's `verify` in the worktree (skip it when it is just `test_cmd`, which runs after the merge anyway). All good → merge (step 5). Any doubt — diff larger than expected, off-card files, acceptance not obviously met, NOTES report a deviation — → treat the card as `M` and put it in the verify queue.
   - `DONE`, size `M`/`L`, or any retried card → mark `verifying` and add it to the **verify queue**.
   - **Batched verifier**: dispatch one verifier for the whole queue (at most 3 cards per verifier) as soon as the queue holds 3 cards **or** no executor is still running (nothing else will join soon). The prompt gives the absolute plan.md path and, per card, the task id, WORKTREE and base commit (the verifier reads the cards itself). A batch verifier counts as one agent in the concurrency limit. Each card in its report gets its own verdict; handle them independently.
   - `BLOCKED` → your call: if you can add the missing information, re-dispatch; otherwise mark `blocked` and keep the others moving.
   - `FAILED`, the verifier returns `FAIL` for a card, or an S card fails your light check in a way that needs code changes → `attempts+1`. While `attempts < 3`, send the failure reason and the concrete PROBLEMS to **the same executor with SendMessage** (it already knows the code, so this is far cheaper than a fresh start) and tell it to fix, commit and report again. Start a new executor on the same branch instead only when the original was a Haiku `S` executor (the retry moves to Sonnet) or SendMessage fails. On the third failure, take over and fix it yourself (Opus); if that fails too, mark `failed`.
5. Card passed (verifier `PASS` or S light check OK) → **merge immediately**: on `concerto/<plan-id>`, `git merge --no-ff <task-branch>` (merges are serial, one at a time), then run `test_cmd` with quiet flags and only the tail of its output (e.g. `pytest -q 2>&1 | tail -15`); look at the full output only when it fails.
   - Conflicts: resolve simple ones yourself; for complex ones dispatch an executor on the integration branch.
   - Test failure: the card or its interaction with already-merged cards is at fault; dispatch a fix card on the same branch (it goes through the verifier). If it cannot be fixed, roll back the merge and mark `failed`.
   - Merge succeeded → mark `done`, record branch and commit, then return to step 1 so cards unblocked by this one start immediately.
6. Downstream cards of a `failed`/`blocked` card are marked `blocked` and not dispatched.
7. **Write every state change back to plan.md immediately and append a line to log.md**, so an interrupted run can resume. Change only the affected fields with small edits (or `sed`/`echo >>`); never rewrite the whole file.
8. **Quality is not traded for speed**: no card is merged without either your S light check or an independent verifier `PASS`, followed by `test_cmd`. Batching and tiering save tokens; skipping verification is never allowed.

## Phase 4: Wrap-up
1. After everything completable is merged, run the full `test_cmd` on the integration branch.
2. All green and no failed cards → switch to `base_branch` and `git merge --ff-only concerto/<plan-id>` (use `--no-ff` if a fast-forward is impossible); mark the plan `done`. Any failed or blocked card → **do not merge back**, stay on the integration branch, mark the plan `partial`.
3. If you autostashed earlier → `git stash pop`; on conflict keep the stash and tell the user.
4. Idea pool: tick as `- [x]` (with the plan-id appended) **only the lines listed in this plan's `ideas:` field**. Never tick ideas that were added while the round was running.
5. Clean up: delete merged task branches and their worktrees (`git worktree prune`). **Never push, never force.**
6. **Automatic next round (at most 3 consecutive rounds)**: after cleanup, re-read `.claude/work/ideas.md`. If there are `- [ ]` ideas added during the run, this is round < 3, and this round had no failed card (if it did, let the user look first) → go straight back to Phase 1 with those ideas (new plan-id, based on the freshly merged `base_branch`) without asking. If round 3 is done and ideas remain, stop and say "N ideas left; run /opus again to continue". Log it as `round k/3`; a manual `/opus` counts from round 1 again.
7. Send a one-sentence result with PushNotification, e.g. "concerto done: 5/5 ✓" or "concerto partial: 4/5, T3 failed".
8. Final report to the user (one combined report, one short section per round), at most 15 lines: one line per task (✓/✗ + title + one sentence), test result, current branch, reason and suggested next step for failed tasks, and a summary of executor FINDINGS (suggest adding them to the idea pool).

## Principles
- Design judgement stays with you; hand the legwork to Sonnet. Never dispatch a vague card.
- Do not write large implementations yourself (Phase 0 small changes and take-over fixes excepted).
- If no "Must ask" case occurred, do not stop and do not ask "continue?".
