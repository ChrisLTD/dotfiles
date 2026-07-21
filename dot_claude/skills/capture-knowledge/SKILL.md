---
name: capture-knowledge
description: Capture a durable business/system fact into the agent-docs knowledge base (~/work/agent-docs/knowledge/) with provenance, following the capturing-knowledge playbook. Use when the user wants to save a fact, decision, or gotcha for future sessions — "capture this", "add to the knowledge base", "remember this for other repos", "save this decision" — or when a session ends having surfaced durable cross-task knowledge worth keeping. For repo-scoped code facts or style rules, this skill routes to repo-notes/ or conventions/ instead.
---

# capture-knowledge

Capture knowledge into `~/work/agent-docs/knowledge/`. The authoritative playbook is `~/work/agent-docs/capturing-knowledge.md` — **read it first and follow it**; this skill only orders the steps.

1. Read `~/work/agent-docs/capturing-knowledge.md` in full.
2. Apply **the filter** (durable + cross-task + not cheaply derivable). If the fact fails the filter, route it instead:
   - repo-scoped code fact → the repo's section in `~/work/agent-docs/repo-notes/<repo>.md` (then re-install that wrapper to `~/work/<repo>/CLAUDE.local.md`, and to `~/work/measured-app-*` clones for measured-app)
   - style/API-usage rule → `~/work/agent-docs/conventions/go.md` or `conventions/ts.md`
   - neither → tell the user why it doesn't belong, don't write it
3. Check `knowledge/INDEX.md` for an existing note to update before creating a new one.
4. Draft the note from `knowledge/_template.md`. Verify every checkable claim against the code now and cite the file/call chain in Evidence — no citation, no note. For Slack sources follow the playbook's Slack section (verbatim quotes with attribution; permalink AND text).
5. Add or update the INDEX line as a retrieval hook (the question the note answers), set `verified:` to today.
6. Show the user the note before committing. Then commit and push agent-docs with a one-line message describing the fact.
