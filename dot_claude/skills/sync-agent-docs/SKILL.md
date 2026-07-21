---
name: sync-agent-docs
description: Reconcile the agent-docs repo (~/work/agent-docs) with the installed CLAUDE.local.md wrappers across all measured-fi checkouts — diff both directions, reinstall, commit and push. Use after editing a wrapper, conventions file, or knowledge note, or when the user says "sync agent docs", "reinstall the wrappers", or "push the conventions".
---

# sync-agent-docs

Keep `~/work/agent-docs` and the installed wrappers in sync. Wrappers are **copies, not symlinks** — `repo-notes/<repo>.md` in the repo mirrors `~/work/<repo>/CLAUDE.local.md` live.

Repos: `admin-gateway api-gateway partner identity requirement jobs measured-app`, plus any `~/work/measured-app-*` clones (which receive copies of `measured-app.md`).

1. `git -C ~/work/agent-docs pull`, then `git -C ~/work/agent-docs status` — note any uncommitted edits.
2. Diff every pair: `diff ~/work/agent-docs/repo-notes/<repo>.md ~/work/<repo>/CLAUDE.local.md`. (measured-app clones should match `measured-app.md`.)
3. For each difference, decide direction by which side has the newer intentional edit — ask the user if unclear; never silently overwrite a side that has content the other lacks:
   - live wrapper edited → copy into `repo-notes/`
   - repo-notes / conventions / knowledge edited → copy out to the live wrapper(s)
4. Reinstall so everything matches:
   ```sh
   for r in admin-gateway api-gateway partner identity requirement jobs measured-app; do
     cp ~/work/agent-docs/repo-notes/$r.md ~/work/$r/CLAUDE.local.md
   done
   for d in ~/work/measured-app-*; do
     [ -d "$d/.git" ] && cp ~/work/agent-docs/repo-notes/measured-app.md "$d/CLAUDE.local.md"
   done
   ```
5. Skills are mirrored the same way: `~/work/agent-docs/skills/<name>/SKILL.md` ↔ `~/.claude/skills/<name>/SKILL.md`. Diff each pair and reconcile in the same newer-intentional-edit direction.
6. Verify: `git -C ~/work/<repo> check-ignore -q CLAUDE.local.md` passes everywhere; spot-check one wrapper's `@` import lines resolve to files that exist.
7. Commit and push agent-docs if it changed.
