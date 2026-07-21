---
name: refresh-conventions
description: Refresh the agent-docs convention files from PR review feedback received since the last refresh, following the generating-conventions playbook (fetch merged PRs, analyze comments, update conventions/go.md, conventions/ts.md, and repo wrappers). Use when the user says "refresh the conventions", "analyze my recent PR feedback", or "update the conventions from new PRs".
---

# refresh-conventions

Refresh `~/work/agent-docs/conventions/` from recent PR feedback. The authoritative playbook is `~/work/agent-docs/generating-conventions.md` — **read it first and follow it**; this skill only adds the incremental-refresh specifics.

1. Read `~/work/agent-docs/generating-conventions.md` in full.
2. Determine the cutoff: the last refresh commit in agent-docs history (`git -C ~/work/agent-docs log --oneline -- conventions/`), or ask the user. Only fetch PRs with `mergedAt` after it.
3. Scope: Go repos (`admin-gateway api-gateway identity jobs partner requirement`) refresh `conventions/go.md`; `measured-app` refreshes `conventions/ts.md`. Run whichever the user asked for, or both.
4. Follow the playbook steps 2–7. Refresh-specific rules:
   - New recurring themes get added; themes with no new occurrences since last refresh can be trimmed from "My recurring mistakes" (they worked) — but conventions themselves stay unless proven wrong.
   - Evidence goes append-only into the analysis docs (`pr-feedback-patterns.md` for Go, `app-pr-feedback-patterns.md` for measured-app).
   - Business/system facts uncovered along the way go to `knowledge/` (see `capturing-knowledge.md`), not into conventions — conventions are style and API usage only.
   - Verify disputed rules against source before writing them (playbook §6).
5. While in the area: sweep the stalest `knowledge/` notes (`grep -r 'verified:' ~/work/agent-docs/knowledge/ | sort -t: -k3`) and re-verify the oldest few.
6. Finish with the sync-agent-docs skill (reinstall wrappers, commit, push).
