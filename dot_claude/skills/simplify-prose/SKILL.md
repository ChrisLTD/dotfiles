---
name: simplify-prose
description: Launch a Sonnet sub-agent to simplify the code comments and PR description the main model just wrote — deleting narration comments, tightening "why" comments, and drafting a shorter PR description in the user's voice. Use after finishing a branch or opening a PR, or when the user says "simplify the comments", "trim the comments", "deslop this", "tighten the PR description", or "run the prose pass".
---

# Simplify prose

Hand the branch's comments and PR description to a fresh Sonnet sub-agent for a simplification pass. Comment edits and the rewritten PR description are both applied directly, with the old description saved so it can be restored on request.

## Step 1: Determine scope

Check whether a PR exists with `gh pr view --json number,baseRefName`. If yes, use its base branch and note the PR number. If not, use the default branch (`git symbolic-ref refs/remotes/origin/HEAD`).

## Step 2: Launch the prose-simplifier agent

Launch the `prose-simplifier` agent (one agent, foreground) with the base branch and PR number (if any). Tell it to edit comments on the diff's added/changed lines directly and to return a drafted PR description without posting it.

## Step 3: Report the comment edits

Show the agent's edit list numbered for easy reference (top-level: 1., 2., 3.; sub-items: 2a., 2b.). Note that the edits are already applied and reviewable via `git diff`. If the user objects to any item ("3: revert"), revert that hunk.

## Step 4: Post the PR description

If no PR exists, show the draft for later use and stop here.

Otherwise:

1. Save the current title and body first: `gh pr view <number> --json title,body > <scratchpad>/pr-desc-before.json`.
2. Post the draft with `gh pr edit --title --body`, keeping any manually added content (screenshots, video links) the agent carried over.
3. Show the posted title and body verbatim, say it is live on the PR, and offer to revert.

If the user asks to revert, restore the title and body from `pr-desc-before.json`.

## Step 5: Leave the tree uncommitted

Do not commit. The comment edits stay in the working tree for the user to fold into the branch.
