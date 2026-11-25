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

## Where it applies

Any React front-end: a repo where `react` is a dependency in the root `package.json` or in
a workspace package's. Anywhere else, say it does not apply and stop.

The profile was mined from `measured-fi/measured-app`, and he only reviews PRs there. In
any other React repo, run in **portable mode**:

- Use the profile's sections 1 and 2 and the general React, data fetching, forms, styling,
  accessibility, types, and tooling themes.
- Skip what is specific to measured-app: the domain rules, anything naming an `@measured/*`
  package or an app-specific helper, the `[ts.md]` pointers, and the settled and open
  disagreement lists.
- "We already have this" still applies, but against this repo's own helpers and libraries.
- Skip the past-thread lookup by path in step 2; the paths will not match.
- Skip the prediction file in step 4. He will never review the PR, so there is nothing to
  score it against.
- Say in the report that it ran in portable mode.

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
- a weight: **press** (he would follow up if I pushed back or deferred it) or **nit** (he
  would accept "will do in a follow-up"). Judge it by the profile's nit and blocker signals
  in section 1 and by how the precedent thread went: a point he repeated after my reply, or
  has raised on more than one PR, is press. This is not how serious the problem is, only
  how hard he would hold the point.

No finding without a grounding in the profile or a past thread.

## Step 3: Adjudicate

Check each finding against the code and drop the ones that are wrong, saying why. Give each
survivor one outcome:

- **Fix:** mechanical, likely, and you confirmed the fix is right by reading the code.
- **Answer:** a likely judgment finding where the code should stay as it is and the reason
  is clear from the code or this session. Draft the one line that would go in the PR
  description to answer the question before he asks it. Three of these at most; a
  description that pre-argues everything is worse than the questions.
- **Follow-up:** a point that is right, that he would let me defer, and whose fix belongs
  outside this PR: a refactor, a shared component, a backend change, or the next branch in
  the stack. The weight must be nit; he does not accept deferral on a press item. Draft the
  description line that says where it goes. If that needs a ticket that does not exist, say
  so and leave creating it to the user. Two of these at most.
- **Ask:** everything else. Likely judgment findings with no clear answer, anything on the
  profile's open-disagreements list, and all possible findings.

## Step 4: Record and report

In measured-app, write the surviving findings to `predictions/<repo>-<branch with slashes as dashes>.md`,
overwriting any earlier run for the branch. Start the file with the date, the branch, and
the PR number if there is one, then the findings in rank order with their confidence, kind,
weight, and outcome. The refresh scores this file once he has reviewed the PR. Do not commit it
now; the next refresh commits it.

Report the findings numbered for easy reference (1., 2., 3., sub-items 2a., 2b.), grouped
as Fix, Answer, Follow-up, then Ask, press before nit within each group. Each has its
weight and its precedent, and Answer and Follow-up items have their drafted line.

Report only. Do not change code or the PR description until the user says which items to
act on. Never post anything to GitHub from this skill.

## Refresh

1. **Fetch.** Copy `threads.jsonl` to the scratchpad, then run `fetch.sh`. It refuses to
   replace the file if the record count went down. The new records are the ones that are
   not in the old copy, or whose `comments` changed; compare the files rather than going by
   date, so a late reply on an old thread is caught too.
2. **Score predictions.** A prediction file is ready when its PR has merged or closed
   (`gh pr view <number> --repo measured-fi/measured-app --json state`). If the file has no
   PR number, find it with `gh pr list --head <branch> --state all`. Leave files for open
   PRs alone, even if he has already commented; he may not be done.

   For each ready file, list his points on that PR: one per thread, one more for a later
   comment of his that makes a separate point, and one per review summary or PR comment
   with substance. "lgtm" does not count. Then mark each of his points:

   - **hit:** a prediction made the same point about the same change, even if it anchored
     on a different file or line
   - **partial:** the right spot with a different point, the right point on different
     code, or the right point predicted on the neighboring PR in the stack
   - otherwise a miss

   Score every prediction in the file. For each hit, the weight was right if it matches
   how he really held the point: press if his comment was a flat statement with no hedge
   or he came back after my reply, nit otherwise. Append one row per PR to the Live runs
   table in `scorecard.md`, dated today, with a dash under Weight right when the file has
   no weights. Move the file to `predictions/scored/`, creating it if needed.
3. **Update the profile** from the new records:
   - Add new themes at the end of their area, and never renumber existing ones; scored
     prediction files cite themes by number.
   - Bump counts and last-seen months, and add a quote with `#PR` where a newer one is
     clearer. A comment counts toward the one theme it fits best.
   - A comment the predictions missed becomes a theme or a trigger on an existing one.
   - Soften a theme or trigger only once the scorecard's scored files show five or more
     predictions resting on it, across three or more PRs, with no hit. Append a dated
     tally to it and tell the reader to rate it possible; do not delete it.
   - Section 4: a thread where I declined and he neither replied nor raised it again
     before the PR merged goes under settled, marked "no reply". Move it to open
     disagreements if he ever raises it again.
   - Retire a theme when the code it is about is gone from `origin/main` in
     `~/work/measured-app` (`git fetch origin` first, then `git grep <pattern> origin/main`).
   - Recompute the totals in the header and the proportions in section 1, and update the
     "Stack state checked" line with the same import counts.
4. Set `Data through:` to today.
5. Commit and push agent-docs, staging only `reviewers/dwight/`.
