---
description: Generate a Slack PR notification message and copy it to clipboard
---

Generate a Slack message for the current branch's PR and copy it to the clipboard.

1. Get the repo name from `git remote get-url origin` (extract just the repo name, e.g., `measured-app`)
2. Get the PR URL and title using `gh pr view --json url,title`
3. Format the message as: `[repo-name](PR URL) PR title`
4. Copy the message to the clipboard using `pbcopy`
5. Show the user what was copied
