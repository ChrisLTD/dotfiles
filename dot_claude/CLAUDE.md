# User preferences

## PR description style

- Short declarative bullets, one line per change
- No em-dash asides or parenthetical pile-ups
- Don't restate implementation details the diff already shows

## Branching and PRs

- Use git-spice for branch and stack management (`gs branch create`, `gs stack submit`), but only when actually building a stack of dependent branches
- Break multi-part work into stacked branches, one reviewable change per branch
- Open PRs as drafts

### worktrunk (`wt`) for git worktrees

- `wt switch -c <branch>` — create a worktree + branch (add `-b <base>` to branch off something other than default)
- `wt switch <branch>` — switch to a worktree; shortcuts: `^` default branch, `-` previous, `@` current, `pr:<N>` a GitHub PR
- `wt list` — list worktrees and their status
- `wt merge [target]` — squash, rebase, fast-forward into target (default branch), then remove the worktree
- `wt remove` — remove the current worktree, deleting the branch if merged (`-D` to force-delete unmerged)

## Writing in my voice

- Before drafting anything meant to read as me (PR descriptions, review replies, blog posts, commit messages, Slack), read `~/work/agent-docs/voice/VOICE.md` and the per-medium file it points to

## GitHub issues

- Never reply to GitHub issues on my behalf without asking me first
- Prefer drafting a reply for me to copy/paste into GitHub
- Write drafts in my voice, without AI tropes like em dashes

## Coding style and comments

- Do **not** write excessively long, verbose, or frequent comments.
- **Never** add comments to note that "changes were made" or explain the obvious.
- Comments should only be used to explain "why" complex architectural decisions were made, not "what" the code is doing.
- Code should be self-documenting through clear, expressive variable and function names.
