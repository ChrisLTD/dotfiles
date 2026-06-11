---
description: Three-way review roundtable - Claude, Codex, and Copilot review independently, then cross-examine each other's findings
---

Run a two-round review of the current changes with three independent reviewers: you (Claude), Codex, and Copilot.

## Round 1 — independent reviews

1. Determine the scope: the current branch's diff against main (or the relevant base).
2. Launch the `codex-review` and `copilot-review` agents in parallel on that scope.
3. While they run, do your own review in the main context. Read the changed files in full, not just the diff — look for correctness bugs, edge cases, and missing tests. Write your findings down BEFORE reading the agents' results so you aren't anchored by them.
4. Merge all three sets into candidate findings. Deduplicate, and tag each with who flagged it (claude / codex / copilot).

## Round 2 — cross-examination

5. For each finding NOT flagged by all three reviewers, get a rebuttal from the reviewers who missed it:
   - Send codex-review the findings it didn't flag: "Another reviewer claims <finding> at <file:line>. Verify or refute it. Be skeptical — say refuted if it doesn't hold up."
   - Same for copilot-review with the findings it didn't flag.
   - For external findings you didn't flag yourself, verify them by reading the relevant code — don't take either CLI's word for it.
   - Batch the rebuttals: one codex call and one copilot call, run in parallel. One rebuttal round only — no further back-and-forth.

## Verdict

6. Adjudicate each finding as confirmed, contested, or refuted. You are the judge: when reviewers still disagree, read the code and make the call, and say which reviewer you sided with and why.
7. Report, ordered by severity (high / medium / low) within confirmed, then contested. For each item include a consensus score (3/3, 2/3, 1/3) and who flagged it. List refuted findings briefly at the end so the user knows they were considered.
8. Number all items for easy reference (top-level: 1., 2., 3.; sub-items: 2a., 2b.) so the user can respond like "3: please fix" or "2b: stet".

Report only — do not apply any fixes until the user says which items to address.
