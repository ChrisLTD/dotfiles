---
description: Full pre-review polish - panel or roundtable review, apply the fixes, verify, then run the prose pass
argument-hint: "[panel|roundtable]"
---

Take the current branch from "code is written" to "ready for human review" in four stages.
Stages 2 and 3 depend on the user's decisions in stage 1, so do not run ahead.

## Stage 1 — Review

Pick the reviewer flavor from `$ARGUMENTS`:

- `roundtable` — read `~/.claude/commands/roundtable.md` and follow it (Claude + Codex + Copilot).
  Use when the change is risky enough to be worth three independent engines.
- `panel`, or no argument — read `~/.claude/commands/expert-panel.md` and follow it
  (Claude sub-agents, one per expert lens). This is the default.

Follow that file to the letter, including its "report only" rule. Stop after the verdict
and wait for the user to say which numbered items to address.

## Stage 2 — Apply

Apply only the items the user picked. For anything they marked "stet" or skipped, leave the
code alone — do not sneak fixes in. If applying a fix reveals that the finding was wrong,
say so and stop rather than forcing the change.

## Stage 3 — Verify

Run the project's verify steps (`.claude/commands/verify.md` in this repo if it exists,
otherwise the project's own static/test/build commands). Fix what breaks and re-run the
failing check until it passes. Do not proceed with failures outstanding.

## Stage 4 — Prose

Invoke the `simplify-prose` skill. It runs last on purpose: the fixes from stage 2 add new
comments, and the PR description should describe the branch as it finally stands.

## Wrap-up

Report in one block: which review flavor ran, how many findings were confirmed and how many
the user chose to fix, the verify result, and the count of comment edits the prose pass made.
Leave everything uncommitted unless the user asks otherwise.
