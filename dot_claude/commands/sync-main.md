---
description: Merge latest main into the current branch and resolve conflicts
---

Bring the current branch up to date with main.

1. `git fetch origin`
2. Merge `origin/main` (or `origin/master`) into the current branch. Use merge, not rebase.
3. Resolve any conflicts by understanding the intent of both sides — check `git log` / blame on conflicting hunks when unclear. If a resolution requires a judgment call you're not confident about, flag it and ask rather than guessing.
4. After resolving, run the repo's static checks if defined (e.g. `pnpm static`), and tests for affected packages.
5. Summarize each conflict and how it was resolved. Commit the merge, but do not push unless asked.
