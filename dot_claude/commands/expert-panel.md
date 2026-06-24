---
description: Panel-of-experts review - several Claude sub-agents each review through a distinct expert lens, then cross-examine before you adjudicate
---

Run a two-round review of the current changes as a panel of expert reviewers, each a separate Claude sub-agent with a distinct lens. You are the chair: you convene the panel, moderate the cross-examination, and deliver the verdict — you do not cast a finding of your own in round 1.

## Round 1 — convene the panel

1. Determine the scope: the current branch's diff against main (or the relevant base). Get both the diff and the list of changed files.
2. Read the diff yourself first — not to find bugs, but to choose the panel. Pick **3–5 expert lenses that fit what the change actually touches**. Draw from lenses like:
   - **Correctness / bugs** — logic errors, edge cases, null/empty/boundary handling, race conditions.
   - **Security** — injection, authz, secret handling, unsafe input. Skip on changes with no trust boundary (e.g. pure docs).
   - **Performance / efficiency** — hot paths, N+1s, needless allocation or IO.
   - **Maintainability / API design** — naming, cohesion, public surface, future-proofing, simplification.
   - **Testing / coverage** — missing cases, brittle assertions, untested branches.
   - **UI/UX** — visual hierarchy, interaction patterns, affordances, error states, empty states, loading states, accessibility (ARIA, focus, contrast), responsiveness. Apply when the diff touches UI components, templates, styles, or user-facing copy.
   - **Domain-specific** — add a lens the diff demands (concurrency, data migration, shell/templating safety, etc.) and drop ones that don't apply.

   Name the panel you chose and say in one line why each lens earned a seat.
3. Spawn one Claude sub-agent per lens, **in parallel** (one message, multiple Agent tool calls, `general-purpose` type). Give every expert the same scope and this charge:
   - "You are the **<lens>** reviewer on a review panel. Review only through your lens. Read the changed files in full, not just the diff. Report concrete findings with `file:line`, a severity (high/medium/low), and a one-line rationale each. Be specific and skeptical of your own findings — omit anything you can't defend. Return nothing if your lens turns up nothing."
4. Collect all panels' findings into candidate items. Deduplicate across lenses, and tag each with which expert(s) raised it.

## Round 2 — cross-examination

5. For each finding **not** raised by every expert, get a rebuttal from the experts who missed it. Spawn skeptic sub-agents in parallel (batch the findings — roughly one agent per reviewing lens, not one per finding):
   - "Another panelist claims: <finding> at <file:line>. Verify or refute it by reading the code. Be skeptical — say **refuted** if it doesn't hold up, **confirmed** if it does, **contested** if it's a judgment call, and give your reasoning."
   - Verify the most consequential findings yourself by reading the code — don't take any sub-agent's word for a high-severity claim.
   - One rebuttal round only. No further back-and-forth.

## Verdict

6. Adjudicate each finding as **confirmed**, **contested**, or **refuted**. You are the judge: when the panel still disagrees, read the code and make the call, and say which expert you sided with and why.
7. Report, ordered by severity (high / medium / low) within confirmed, then contested. For each item include a consensus score (e.g. 3/4) and which lenses flagged it. List refuted findings briefly at the end so the user knows they were considered.
8. Number all items for easy reference (top-level: 1., 2., 3.; sub-items: 2a., 2b.) so the user can respond like "3: please fix" or "2b: stet".

Report only — do not apply any fixes until the user says which items to address.
