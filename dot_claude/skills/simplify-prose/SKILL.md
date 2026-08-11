---
name: simplify-prose
description: Launch a Sonnet sub-agent to simplify the code comments and PR description the main model just wrote — deleting narration comments, tightening "why" comments, and drafting a shorter PR description in the user's voice. Use after finishing a branch or opening a PR, or when the user says "simplify the comments", "trim the comments", "deslop this", "tighten the PR description", or "run the prose pass".
---

# Simplify prose

Hand the branch's comments and PR description to a fresh Sonnet sub-agent for a simplification pass. **Comment edits are applied directly; the PR description is only drafted** — it never goes to GitHub without approval.

## Step 1: Determine scope

Check whether a PR exists with `gh pr view --json number,baseRefName`. If yes, use its base branch and note the PR number. If not, use the default branch (`git symbolic-ref refs/remotes/origin/HEAD`).

## Step 2: Launch the prose-simplifier agent

Launch the `prose-simplifier` agent (one agent, foreground) with the base branch and PR number (if any). Tell it to edit comments on the diff's added/changed lines directly and to return a drafted PR description without posting it.

## Step 3: Report the comment edits

Show the agent's edit list numbered for easy reference (top-level: 1., 2., 3.; sub-items: 2a., 2b.). Note that the edits are already applied and reviewable via `git diff`. If the user objects to any item ("3: revert"), revert that hunk.

## Step 4: Present the PR description draft

Show the drafted title and body verbatim. Only after the user approves, apply with `gh pr edit --title --body`, keeping any manually added content (screenshots, video links) the agent carried over. If no PR exists, just leave the draft for later use.

## Step 5: Leave the tree uncommitted

Do not commit. The comment edits stay in the working tree for the user to fold into the branch.
