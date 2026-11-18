---
description: Roundtable-review the current branch or stack, fix high and medium findings, drop low-value tests, open draft PRs with screenshots, then run the prose pass
argument-hint: "[codex|copilot|both]"
---

Take the current branch, or every branch in its stack, from "code is written" to "draft PR
open and polished" without stopping for approval. `$ARGUMENTS` picks the external reviewer
and defaults to `codex`.

Pass `--no-prompt` to every `gs` command so nothing waits on input. Never pass `--force` or
`--no-verify`. If any restack, push, or submit fails, stop and report rather than working
around it.

## Step 0 — Work out the branch list

Stop if the current branch is the default branch or the working tree is not clean.

Check `git rev-parse -q --verify refs/spice/data` first. `gs` initializes a repo as a side
effect of any command, so do not run it when that ref is missing.

- **Stack mode:** the ref exists, and `gs --no-prompt log short --json` includes an object
  with `"current": true` for this branch plus at least one other non-trunk branch. Without
  the `current` object the branch is untracked and the output is other people's branches,
  not this stack. The objects arrive in no particular order: sort them parents first using
  each one's `down.name`, and drop the trunk. Each branch's base is its `down.name`.
- **Single mode:** anything else. The list is the current branch alone. Its base is its open
  PR's base branch (`gh pr view --json baseRefName`) or, with no PR, the default branch. Do
  not initialize git-spice or track the branch.

Stack mode only: run `gs stack restack` now, so the review sees each branch on top of its
current parent.

## Step 1 — Review, fix, and prune tests, per branch

For each branch in the list, parents first:

1. Check out the branch.
2. Read `~/.claude/commands/roundtable.md` and follow it with the chosen reviewer, with two
   changes. The scope is the diff against this branch's base, not main. Its closing "report
   only" rule does not apply here: confirmed high and medium findings are pre-approved.
3. Fix every confirmed high and medium finding. Leave low, contested, and refuted findings
   alone. If applying a fix shows the finding was wrong, revert that fix and record it as
   skipped with the reason.
4. Invoke the `prune-tests` skill with this branch's base as its argument, so tests written
   for the fixes above are audited too. Its "report only" rule does not apply here: delete
   every candidate that survives its adjudication step. Keep the "weak but sole coverage"
   tests and carry them to the wrap-up.
5. Run the project's verify steps (`.claude/commands/verify.md` in the repo if it exists,
   otherwise its own static, test, and build commands). Fix what breaks and re-run until it
   passes. If it cannot be made to pass, stop the whole run and report.
6. Commit the fixes and test removals, if there are any.
7. Stack mode only: run `gs upstack restack` so the branches above pick up the changes before
   they are reviewed. Resolve a conflict only when the resolution is mechanical, and re-run
   verify on the branch that conflicted. Otherwise stop and report.

## Step 2 — Push and open draft PRs

Follow the repo's PR template and label rules from CLAUDE.md or AGENTS.md. Write each
description per the user's voice instructions. New PRs are drafts. An existing PR keeps
whatever draft status it has.

- **Stack mode:** for each branch, parents first, check whether it has a PR. With one, run
  `gs branch submit`. Without one, run `gs branch submit --draft --fill`, then replace the
  filled-in body with a proper description using `gh pr edit`.
- **Single mode:** `git push -u origin HEAD`. If no PR exists, write the description to a
  scratchpad file and run `gh pr create --draft --base <base> --title <title> --body-file
  <file>`.

Confirm every branch has an open PR before going on. If one does not, stop and report.

## Step 3 — Screenshots, per branch

Skip a branch whose diff has no user-visible UI change. Skip the whole step if the repo has
no way to capture the UI (a screenshot skill such as `pr-screenshots`, or documented
browser automation).

For each remaining branch, parents first:

1. Check out the branch and make sure the app is serving that branch's code.
2. Capture the changed screens with the repo's screenshot skill. Take a before shot from the
   branch's base only when the change is a visual tweak that needs the comparison.
3. Read each image to confirm it shows the change. Drop any that do not.
4. Upload them into the PR description's screenshots section. GitHub only hosts images
   uploaded through its editor, so this goes through the Claude Chrome extension. If the
   extension is not connected, do not retry or wait: keep the files and list their paths in
   the wrap-up for the user to drag in.

This runs before the prose pass because that pass carries existing screenshots over into the
rewritten description.

## Step 4 — Prose pass, per branch

For each branch, parents first, check it out and invoke the `prose-simplify` skill with the
`codex` argument, whichever reviewer was chosen. It commits its comment edits and posts the
rewritten description. Hold its per-branch reports, revert offers, and undo instructions for
the wrap-up instead of printing them as it goes.

Stack mode changes two things:

- Skip the skill's own push. A restack leaves the branches above diverged from their
  remotes, so a plain push is rejected.
- After each branch whose pass made a commit, run `gs upstack restack`, under the same
  conflict rule as step 1. When every branch is done, run `gs stack submit --update-only`
  to push them all.

Return to the branch the run started on.

## Wrap-up

Report in one block, per branch:

- PR link
- Findings fixed, by number and severity
- Findings not fixed: low, contested, and any skipped because the fix proved wrong
- Tests dropped, each with its reason, and any weak ones kept as sole coverage
- Verify result
- Comment edits from the prose pass, and that `pr-desc-before.json` holds the old description
- Screenshots uploaded, or the paths of any left for the user to attach
