---
name: pr-narrative-review
description: Transform a pull request or branch diff into a linear narrative that reads top-to-bottom in the order a reviewer should understand it, with every code block referenced back to its original file and line numbers — as markdown or as a two-pane HTML reader (code left, explanation and concerns right) that can be scrolled or flipped through like a slideshow. Use this skill when the user wants a narrative, walkthrough, reading order, or guided tour of a changeset; trigger on phrases like "what's the story of this change", "walk me through this PR", "linearize this diff", "where should I start reading", or any request for a side-by-side / slideshow / HTML review view. Do NOT trigger on generic "review this PR" requests — those go to the review skills (code-review, cross-review, roundtable); this skill organizes code for a human reviewer instead of finding problems.
---

# PR Narrative Review

Diffs are presented in alphabetical-file order, which is almost never the order in which a change makes sense. This skill turns a changeset into a single document that reads like a story: starting from the conceptual root of the change and proceeding so that every code block's prerequisites have already been explained before it appears. The reviewer reads top to bottom once, then jumps into their editor for the parts that need scrutiny.

The narrative is a **reorganization, not a review**. Describe what the code does and why it appears where it does in the reading order. Do not pass judgment inline — the human is the reviewer. The one exception is the short "Worth scrutinizing" section at the end.

## Step 1: Gather the changeset and its intent

Collect, in order of preference:

1. **PR metadata**: `gh pr view <number> --json title,body,commits,baseRefName,headRefName,files` (or the equivalent for the forge in use). Title, description, and commit messages are the primary evidence of intent.
2. **The diff**: `gh pr diff <number>` or `git diff <base>...<head>`. Use three-dot diff against the merge base, not two-dot.
3. **The actual files at the head ref**: check out or read the post-change files. Diff hunks alone lack the surrounding context needed to write accurate prose and to report correct line numbers. Never narrate from hunks you haven't situated in their files.

If there is no PR (raw diff pasted, local branch), infer intent from commit messages and the shape of the change, and say that you're inferring.

## Step 2: Choose the entry point and declare it

The starting point depends on what kind of change this is. Use these heuristics, but reason from the actual PR rather than forcing a category:

- **New feature / user-facing behavior**: start at the point where the behavior is triggered — the route handler, UI component, CLI command, or event hook — then descend the call graph. Reviewers hold a feature in their head as "user does X, then...".
- **Bug fix**: start at the site of the fix. Open with one paragraph on what the broken behavior was and why, then show the fix, then ripple outward to tests and collateral changes.
- **Refactor**: start with the new abstraction (the new interface, module, or pattern), then show call sites migrating to it, then the deletion of the old path.
- **Data-model or schema change**: start at the schema/types, because everything else in the PR is downstream of the new shape of the data.
- **Mixed PRs**: pick the dominant concern for the spine of the narrative and handle the rest as clearly-labeled side chapters.

At the top of the document, state in one or two sentences which entry point was chosen and why. This is the single most likely place for the narrative to go wrong, and declaring the choice lets the reader correct course immediately instead of discovering a bad ordering halfway through.

## Step 3: Cluster and order the hunks

Group the diff's hunks by concern, not by file — one file may contain hunks belonging to different chapters, and one chapter usually spans several files. Then order the clusters so that:

- A definition appears before its uses (types before functions that consume them, a new helper before its call sites) — **except when the entry-point heuristic from Step 2 says otherwise.** An outside-in feature narrative deliberately shows call sites before definitions; that's fine, because prose can forward-reference ("this calls `useRequestDrawdown`, covered next") in a way raw diffs can't. The rule is: never make the reader depend on something that has been neither shown nor promised.
- A behavioral change appears before the tests that pin it.
- Each chapter ends at a natural seam — a point where the reader could stop and still have a consistent partial model.

Mechanical changes do not belong in the narrative. Renames applied en masse, import churn, lockfiles, generated code, snapshot updates, formatting-only hunks: summarize these in the appendix (Step 5). Dragging them into the story buries the signal the reviewer actually needs.

## Step 4: Write the narrative

Use this structure:

```markdown
# <PR title> — narrative review

**Entry point:** <where the story starts and why, 1–2 sentences>
**Shape:** <N files, M hunks; one sentence on the overall architecture of the change>

## 1. <Chapter title>
<Prose: what this chunk does and how it connects to what came before.>

`src/path/file.ts:42-78` *(modified)*
```ts
<post-change code>
```

## 2. <Next chapter>
...

## Worth scrutinizing
- <2–5 bullets: the riskiest or least-obvious parts, phrased as pointers, not verdicts>

## Appendix: mechanical changes
| File | Change |
|------|--------|

## Jump list
src/path/file.ts:42: 1. <Chapter title>
src/other/file.ts:103: 2. <Next chapter>
```

Rules for code blocks:

- **Show post-change code.** The narrative describes the codebase as it will be. When the old code matters for comprehension (a subtle behavioral change), describe the old behavior in prose, or show a small before/after pair — but make "after" the default.
- **Reference format is `path:start-end` with line numbers in the post-change file**, so the reference is jumpable after checking out the branch. Verify line numbers against the actual head-ref files, not against hunk headers arithmetic — off-by-a-few references erode all trust in the document.
- **Mark each block** as *(added)*, *(modified)*, *(moved from old/path.ts)*, or for deletions, describe them in prose with a reference into the base ref.
- **Include a few lines of unchanged context** when a hunk is incomprehensible without it, and say that you're doing so ("for context, the surrounding function:").
- **Trim aggressively.** A 60-line hunk where 8 lines matter should show the 8 lines with an ellipsis comment, with the full range still given in the reference so the reader can see the rest in their editor.

The **jump list** at the end is a plain-text block, one entry per chapter, in `file:line: title` format (the standard grep/quickfix format). Editor users can load it directly (e.g. Vim's `:cfile`) and step through the PR in narrative order inside their editor.

## Step 5: Verify coverage

Before finishing, diff your document against the changeset: every file in the PR must appear either in a narrative chapter or in the appendix. Run through `git diff --stat` (or the PR's file list) and check each one off. A narrative that silently drops a file is worse than no narrative, because the reviewer believes they've seen everything.

## Output

Two output modes. Unless the user has already indicated a preference (e.g. they asked for a slideshow, or for a markdown doc), ask them which they want before writing the narrative — use the AskUserQuestion tool with the two options, noting that HTML gives a two-pane reader to flip through and markdown stays in the editor/terminal. Ask early (right after Step 1), so the answer is in hand by the time the narrative is written.

**Markdown:** write the document to `.scratch/pr-<number>-narrative.md` (or `.scratch/<branch>-narrative.md` when there's no PR number) at the repo root, creating `.scratch/` if needed, and tell the user where it is. For small changesets (roughly under 150 changed lines), it's fine to also render it directly in the conversation.

**HTML reader:** when the user asks for HTML, a slideshow, a side-by-side view, or something to "flip through", produce `.scratch/narrative.json` and render it with the bundled script:

```bash
node <skill-path>/scripts/render_html.ts .scratch/narrative.json -o .scratch/pr-<number>-narrative.html
```

Requires Node ≥ 22.18 (native type-stripping); on older Node, use `npx tsx` instead of `node`. Syntax highlighting loads highlight.js from cdnjs in the browser — no local install needed; without network access the code renders plain.

The script's header comment documents the full JSON schema. The essentials: top-level `title`, `entry_point`, `shape`, optional `pr_url`; a `chapters` array where each chapter has `title`, `prose` (paragraphs with `inline code`/**bold**/*em* only), optional per-chapter `concerns` (these render as a margin card beside the chapter — prefer attaching concerns to the chapter they belong to rather than one global list), and `blocks` with `path`, `start`, `end`, `status`, `language`, `code`, optional `note`. The `appendix` is a list of `{file, change}` pairs. The jump list is generated automatically from the first block of each chapter — don't build it by hand.

Do not hand-write the HTML; the renderer exists so output is deterministic and consistent across runs. All line-number rules from Step 4 apply identically to the JSON.

## Calibration

- A 2-file typo fix does not need five chapters. Scale the apparatus to the changeset; for trivial PRs, one paragraph plus references is the right output.
- For very large PRs (thousands of lines), narrate the spine in full and be explicit that leaf-level changes are summarized; offer to expand specific chapters on request.
- If the PR description and the code disagree about intent, say so prominently — that disagreement is itself one of the most valuable things a reviewer can learn from this document.
