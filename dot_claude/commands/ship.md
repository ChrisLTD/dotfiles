---
description: Roundtable-review the current branch or stack, fix high and medium findings, open draft PRs, then run the prose pass
argument-hint: "[codex|copilot|both]"
---

Take the current branch, or every branch in its stack, from "code is written" to "draft PR
open and polished" without stopping for approval. `$ARGUMENTS` picks the external reviewer
and defaults to `codex`.

## Step 0 — Work out the branch list

Run `gs --no-prompt log short --json`.

- **Stack mode:** the command succeeds and lists more than one non-trunk branch. The list is
  those branches, bottom-up. Each branch's base is its parent in the stack.
- **Single mode:** anything else, including the command failing because the repo is not
  initialized for git-spice or the branch is untracked. The list is the current branch alone.
  Its base is its open PR's base branch (`gh pr view --json baseRefName`) or, with no PR, the
  default branch. Do not initialize git-spice or track the branch.

If the current branch is the default branch, or the working tree has uncommitted changes that
are not part of the work being shipped, stop and say so.

## Step 1 — Review and fix, per branch

For each branch in the list, bottom-up:

1. Check out the branch.
2. Read `~/.claude/commands/roundtable.md` and follow it with the chosen reviewer, with two
   changes. The scope is the diff against this branch's base, not main. Its closing "report
   only" rule does not apply here: confirmed high and medium findings are pre-approved.
3. Fix every confirmed high and medium finding. Leave low, contested, and refuted findings
   alone. If applying a fix shows the finding was wrong, revert that fix and record it as
   skipped with the reason.
4. Run the project's verify steps (`.claude/commands/verify.md` in the repo if it exists,
   otherwise its own static, test, and build commands). Fix what breaks and re-run until it
   passes. If it cannot be made to pass, stop the whole run and report.
5. Commit the fixes, if there are any.
6. Stack mode only: run `gs upstack restack` so the branches above pick up the fixes before
   they are reviewed. If the restack hits a conflict that is not a mechanical resolution,
   stop and report.

## Step 2 — Push and open draft PRs

Follow the repo's PR template and label rules from CLAUDE.md or AGENTS.md. Write each
description per the user's voice instructions.

- **Stack mode:** `gs stack submit --draft --fill`, then replace each new PR's filled-in
  body with a proper description using `gh pr edit`.
- **Single mode:** `git push -u origin HEAD`. If no PR exists, `gh pr create --draft` against
  the base from step 0. If one exists, leave its draft status as it is.

## Step 3 — Prose pass, per branch

For each branch, bottom-up, check it out and invoke the `prose-simplify` skill with the
`codex` argument, whichever reviewer was chosen. It commits its comment edits and posts the
rewritten description.

Stack mode only: after each branch whose pass made a commit, run `gs upstack restack`. When
every branch is done, run `gs stack submit` once more to push the restacked branches.

Return to the branch the run started on.

## Wrap-up

Report in one block, per branch:

- PR link
- Findings fixed, by number and severity
- Findings not fixed: low, contested, and any skipped because the fix proved wrong
- Verify result
- Count of comment edits from the prose pass
