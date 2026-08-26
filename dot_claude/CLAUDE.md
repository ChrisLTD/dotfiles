# User preferences

## PR description style

- Short declarative bullets, one line per change
- No em-dash asides or parenthetical pile-ups
- Don't restate implementation details the diff already shows

## Branching and PRs

- Use git-spice for branch and stack management (`gs branch create`, `gs stack submit`), but only when actually building a stack of dependent branches
- Break multi-part work into stacked branches, one reviewable change per branch
- Lean toward splitting a PR into a stack when lines added exceed ~1,000 (excluding generated/vendored code like lockfiles or codegen output; test code still counts)
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

## Browser automation

- `playwright-cli` (`npm install -g @playwright/cli@latest`) drives a long-lived browser from single shell commands. Use it to click through a running app, confirm a UI change, or pull real locators off a page without authoring a spec.
- It ships its own agent skill covering the full command surface; the path is printed at the top of `playwright-cli --help`. Don't restate those commands in notes, and don't track a copy in this repo, since npm regenerates it.
- Repo-specific setup (auth reuse, local ports, testid conventions) belongs in that repo's docs. For measured-app, see "Browser automation for agents" in `e2e/README.md`.
- Name sessions (`-s=advisor`) and close them when done; they outlive the command that created them.
