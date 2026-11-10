---
name: prose-simplify
description: Hand the code comments and PR description the main model just wrote to a fresh editor (a Sonnet sub-agent by default, or Codex) that deletes narration comments, tightens "why" comments, and drafts a shorter PR description in the user's voice. Use after finishing a branch or opening a PR, or when the user says "simplify the comments", "trim the comments", "deslop this", "tighten the PR description", or "run the prose pass".
argument-hint: "[sonnet|codex]"
---

# Prose simplify

Hand the branch's comments and PR description to a fresh editor for a simplification pass. Comment edits are applied and committed, and the rewritten PR description is posted, with the old description saved so it can be restored on request.

`$ARGUMENTS` picks the editor: `sonnet` (default) runs the `prose-simplifier` sub-agent; `codex` runs the same instructions through the Codex CLI.

## Step 1: Determine scope

Check whether a PR exists with `gh pr view --json number,baseRefName`. If yes, use its base branch, note the PR number, and save the current title and body: `gh pr view <number> --json title,body > <scratchpad>/pr-desc-before.json`. If not, use the default branch (`git symbolic-ref refs/remotes/origin/HEAD`).

## Step 2: Run the editor

Both editors get the same brief: the base branch, the PR number and the path to `pr-desc-before.json` (if a PR exists), and the instruction to edit comments on the diff's added/changed lines directly and return a drafted PR description without posting it.

- `sonnet`: launch the `prose-simplifier` agent (one agent, foreground) with that brief.
- `codex`: the agent file's body is the prompt. Write the brief plus that body to a scratchpad file, then run codex from the repo root as its own command:

  ```sh
  { echo "Base branch: <base>. PR: <number or none>. Current PR title/body: <path or none>."; awk 'c>=2{print} /^---$/{c++}' ~/.claude/agents/prose-simplifier.md; } > <scratchpad>/prose-prompt.md
  codex exec --skip-git-repo-check -s workspace-write -m gpt-6.1-sol -c model_reasoning_effort="medium" -o <scratchpad>/prose-codex.md - < <scratchpad>/prose-prompt.md
  ```

  Keep these as two separate Bash calls. The `codex exec` prefix has a permissions allow rule, which only matches when the command starts with it.

  Read the edit list and draft from `prose-codex.md` rather than scraping the transcript. The workspace-write sandbox lets Codex edit files but blocks network, which is why the PR title and body travel as a file instead of a `gh` call.

## Step 3: Report the comment edits

Show the editor's edit list numbered for easy reference (top-level: 1., 2., 3.; sub-items: 2a., 2b.). Note that the edits are already applied and reviewable via `git diff`. If the user objects to any item ("3: revert"), revert that hunk, and amend the commit if Step 5 already ran.

## Step 4: Post the PR description

If no PR exists, show the draft for later use and stop here.

Otherwise:

1. Post the draft with `gh pr edit --title --body`, keeping any manually added content (screenshots, video links) the editor carried over.
2. Show the posted title and body verbatim, say it is live on the PR, and offer to revert.

If the user asks to revert, restore the title and body from `pr-desc-before.json`.

## Step 5: Commit the comment edits

Stage only the files the editor edited, not unrelated work in the tree. Commit them with a short message such as `Simplify comments`. Skip this step if the editor made no comment edits.

If those files also carry uncommitted changes from before the pass, they ride along in the commit. Say so in the report and pick a message that covers the whole set.

If the branch has an upstream, push so the PR matches the description that was just posted.

Report the commit and tell the user how to undo it (`git reset HEAD~1`).
