---
name: dwight-review
description: Review the current branch the way Dwight would, using a profile mined from his past review comments on my PRs, so his feedback is handled before he has to give it. Use before opening or un-drafting a PR, or when the user says "dwight review", "what would Dwight say", or "run the Dwight pass". Pass "refresh" to re-mine his comments, score past predictions, and update the profile.
argument-hint: "[base-branch | refresh]"
---

# Dwight review

Predict the comments Dwight would leave on this branch. This is not a general code review:
a finding belongs here only if his history says he would raise it.

The data lives in `~/work/agent-docs/reviewers/dwight/`:

- `profile.md`: how he reviews, the questions he asks, and his themes by code area
- `threads.jsonl`: every comment he has left on my PRs, one record per thread
- `fetch.sh`: rebuilds `threads.jsonl`
- `predictions/`: what this skill predicted, one file per branch
- `scorecard.md`: how those predictions compared with what he really wrote

If `profile.md` is missing, say so and stop. If `$ARGUMENTS` is `refresh`, do the Refresh
section and stop.

Predictions are experimental until the scorecard says otherwise. In the backtest the top
finding matched a real comment of his about half the time, and most of the rest were things
he did not raise. So this skill only reports. The one other caller is `/roundtable`, and
only when its arguments include `dwight`. Do not apply findings without the user picking
them.

## Step 0: Refresh if stale

If the profile's `Data through:` date is more than 14 days old, do the Refresh section
first. If it fails (offline, `gh` not authenticated), carry on with the stale profile and
say so in the report.

## Step 1: Determine scope

The base is `$ARGUMENTS` if given. Otherwise it is the open PR's base branch
(`gh pr view --json baseRefName`), or with no PR, the default branch
(`git symbolic-ref refs/remotes/origin/HEAD`).

The review covers the diff from the merge base to the working tree, plus the PR title and
description: the open PR's, or the draft from this conversation if there is no PR yet. He
reads the description closely and disputes claims in it, so pass it along whenever one
exists.

## Step 2: Review

Launch one general-purpose sub-agent, foreground. A fresh reader is the point: the session
that wrote the code already believes its own reasoning. Give it the base branch, the PR
description, the paths above, and these instructions:

1. Read `profile.md` in full, then the diff.
2. For each changed file, pull what he has said there before, then widen to the directory:

   ```sh
   jq -c --arg p "<path>" 'select(.kind == "thread" and (.path | startswith($p))) | {pr, createdAt, path, comments}' threads.jsonl
   ```

   A past comment on the same file or a sibling file is the strongest predictor there is.
3. Read the code around each change, not just the hunk. Before predicting "use the existing
   helper" or "this already exists", find the helper and name it. Before predicting "the
   sibling app needs this too", open the sibling.
4. Go through the profile's questions one at a time against the diff and the description.
   These are judgment calls about design and scope, and they are most of what he writes.
5. Report only. Do not edit anything.

He leaves about two comments on a typical PR. Rank the findings by how sure you are he
would write that comment, and give at most six. Each finding has:

- `file:line`, or "PR description"
- the comment written the way he would phrase it
- the profile theme or past thread it rests on, with `#PR`
- a confidence: **likely** (he has said this about this kind of change before) or
  **possible** (in character, no direct precedent)
- a kind: **mechanical** (one obvious fix that needs no decision from me) or **judgment**
  (a question about design, scope, or behavior). Anything touching the profile's open
  disagreements is judgment.

No finding without a grounding in the profile or a past thread.

## Step 3: Adjudicate

Check each finding against the code and drop the ones that are wrong, saying why. Give each
survivor one outcome:

- **Fix:** mechanical, likely, and you confirmed the fix is right by reading the code.
- **Answer:** a likely judgment finding where the code should stay as it is and the reason
  is clear from the code or this session. Draft the one line that would go in the PR
  description to answer the question before he asks it. Three of these at most; a
  description that pre-argues everything is worse than the questions.
- **Ask:** everything else. Likely judgment findings with no clear answer, anything on the
  profile's open-disagreements list, and all possible findings.

## Step 4: Record and report

Write the surviving findings to `predictions/<repo>-<branch with slashes as dashes>.md`,
overwriting any earlier run for the branch. Start the file with the date, the branch, and
the PR number if there is one, then the findings in rank order with their confidence, kind,
and outcome. The refresh scores this file once he has reviewed the PR. Do not commit it
now; the next refresh commits it.

Report the findings numbered for easy reference (1., 2., 3., sub-items 2a., 2b.), grouped
as Fix, Answer, then Ask, each with its precedent, and for Answer items the drafted line.

Report only. Do not change code or the PR description until the user says which items to
act on. Never post anything to GitHub from this skill.

## Refresh

1. Note the profile's `Data through:` date, then run `fetch.sh`.
2. Score predictions. For each file in `predictions/` whose PR now has comments from him
   in `threads.jsonl` or has merged, compare the predictions with what he wrote: a **hit**
   is the same point on the same code, a **partial** is the right spot with a different
   point or the right point elsewhere. Append one row per PR to `scorecard.md` (date, PR,
   his comment count, hits, partials, how many predictions, whether the top-ranked one
   hit) and move the file to `predictions/scored/`. A PR he approved without comment still
   gets a row.
3. Read the records newer than the old `Data through:` date and update `profile.md`: add
   new themes, bump counts and last-seen months, and add quotes with `#PR` where a newer
   one is clearer. Give extra weight to comments the predictions missed. Move a theme to
   the retired list when the code it is about is gone, and soften one that has produced
   several predictions with no hit.
4. Set `Data through:` to today.
5. Commit and push agent-docs.
