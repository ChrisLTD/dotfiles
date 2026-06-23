---
name: pr-feedback
description: Pull unresolved review feedback on the current PR, triage each comment (Definitely fix / Maybe fix / Nit / Don't fix), apply the fixes you approve, and draft replies to every comment in your voice. Use when the user wants to address PR review comments, work through reviewer feedback, handle unresolved threads, or respond to a code review. Trigger on phrases like "address the PR feedback", "go through the review comments", "what's left to fix on this PR", "respond to the reviewers", or "handle the unresolved comments".
---

# Address PR feedback

Work through the unresolved review threads on a pull request: fetch them, triage each into an actionable bucket, get approval before changing code, make the approved fixes, and draft a reply for every thread. **Default to drafting, not posting** — the user reviews and posts replies / resolves threads themselves unless they explicitly tell you to post.

"Unresolved feedback" means review threads on the PR that have not been marked resolved. That resolved/unresolved state lives only in GitHub's GraphQL API, so use the helper script rather than `gh pr view` or the REST comments endpoint.

## Step 1: Identify the PR

```bash
gh pr view --json number,title,url,headRefName
```

If there's no PR for the current branch, ask the user for a PR number (the helper script accepts one as an argument). Don't guess.

## Step 2: Fetch the unresolved threads

```bash
bash <skill-path>/scripts/fetch-unresolved.sh [PR_NUMBER]
```

It prints a JSON array, one object per unresolved thread:

```json
{
  "threadId": "PRRT_…",        // for resolving the thread later
  "path": "src/foo.ts",
  "line": 42,
  "isOutdated": false,           // true = the code moved since the comment
  "url": "https://github.com/…", // link to the first comment
  "replyToId": 123456789,        // first comment id, for posting a reply
  "comments": [ { "author": "...", "body": "...", "createdAt": "...", "diffHunk": "..." } ]
}
```

If the array is empty, tell the user there's no unresolved feedback and stop.

Threads can have a back-and-forth — read the whole `comments` list, not just the first one, so a reply you draft accounts for the latest state of the discussion. Note `isOutdated` threads: the referenced code may have already changed.

## Step 3: Read the code around each comment

For every thread, open the file at `path` near `line` and read enough surrounding code to judge what the reviewer is asking and whether it still applies. The `diffHunk` shows what the reviewer saw; the current file shows what's there now. Don't triage from the comment text alone.

## Step 4: Triage into buckets

Classify each thread into exactly one bucket:

- **Definitely fix** — a real bug, correctness issue, or a clear, uncontroversial improvement the reviewer asked for.
- **Maybe fix** — reasonable but debatable, a matter of taste, or needs a decision/trade-off the user should make.
- **Nit** — trivial style/wording/formatting; harmless to skip.
- **Don't fix** — already addressed, based on a misunderstanding, out of scope, or something to push back on. Say why.

Present a numbered table the user can respond to tersely. Number items with an ever-incrementing scheme (1, 2, 3…). Keep each row to one line where possible:

| # | Bucket | File:line | Reviewer | Summary | Proposed action |
|---|--------|-----------|----------|---------|-----------------|

For **Don't fix** rows, the "Proposed action" is the gist of the pushback you'd reply with.

## Step 5: Get approval before touching code

Ask which items to fix. Default proposal: fix everything in **Definitely fix** and **Nit**, hold **Maybe fix** for the user to decide, skip **Don't fix**. Let the user override per item by number ("1, 3: fix", "4: stet", "2: leave a reply pushing back").

Do not edit any code until the user approves. Use `AskUserQuestion` if a Maybe-fix needs a real decision between alternatives.

## Step 6: Apply the approved fixes

Make the approved edits, grouped logically. Keep changes minimal and matched to the surrounding code style. Note which thread each edit answers so the drafted replies in the next step line up. Run the project's tests/linters if that's the norm for the repo. Do not commit or push unless asked.

## Step 7: Draft replies for every thread

Draft one reply per thread, in the user's voice. Honor the user's writing preferences from their CLAUDE.md:

- Plain, direct, first person ("Fixed — moved the guard up", "Good catch", "Leaving this as-is because…").
- No AI tropes, no em-dash asides, no throat-clearing.
- For fixed items, say what changed in a few words. For Don't-fix / pushback items, give the reason plainly and leave room for the reviewer to disagree.

Present the drafts as a numbered list matching the triage table, formatted for easy copy/paste. **Do not post them.**

## Step 8 (optional): Post replies and resolve threads

Only if the user explicitly asks you to post. Then, per thread:

Post a reply to a thread:
```bash
gh api repos/{owner}/{repo}/pulls/{PR}/comments/{replyToId}/replies \
  -f body="…"
```

Resolve a thread (after a fix is pushed and the reply is posted):
```bash
gh api graphql -f query='
  mutation($id:ID!) { resolveReviewThread(input:{threadId:$id}) { thread { isResolved } } }
' -F id="{threadId}"
```

Confirm with the user before resolving — resolving is theirs to decide, and replies that fix code should generally be pushed first.
