---
name: publish-narrative
description: Publish a pr-narrative-review as a private Claude Artifact and return the shareable link. Use when the user wants to share or archive a narrative review, mentions "publish the narrative", "share the narrative", or "publish this review".
---

# Publish Narrative

Publishes the narrative produced by `/pr-narrative-review` as a Claude Artifact — a page hosted on claude.ai that is private to the user's account until they choose to share it. No repo, GitHub Pages, or first-run setup: it's one call to the Artifact tool.

## Step 1: Find the narrative source

`/pr-narrative-review` writes the narrative JSON to `.scratch/`. Publishing re-renders from that JSON, so the JSON — not the HTML — is what's needed.

- If a PR number was passed as args, use `.scratch/pr-<number>-narrative.json`.
- Otherwise pick the most recently modified match:
  ```bash
  ls -t .scratch/*-narrative.json 2>/dev/null | head -1
  ```
- If no JSON is found, tell the user to run `/pr-narrative-review` first.

## Step 2: Render a self-contained HTML

Claude Artifacts run under a strict CSP that blocks external scripts and wrap the page in their own `<head>`/`<body>`. The renderer's `--self-contained` flag produces the required shape: highlight.js inlined, no outer `<html>`/`<head>` wrapper.

```bash
node ~/.claude/skills/pr-narrative-review/scripts/render_html.ts \
  .scratch/pr-<number>-narrative.json \
  -o .scratch/pr-<number>-narrative.artifact.html \
  --self-contained
```

The first run fetches highlight.js from cdnjs and caches it under `~/.cache/pr-narrative-hljs/`; later runs work offline. Requires Node ≥ 22.18 (or `npx tsx` on older Node).

## Step 3: Publish with the Artifact tool

Read `title` from the narrative JSON, then call the **Artifact** tool with:

- `file_path`: the `.artifact.html` from Step 2
- `title`: `<narrative title> — narrative review`
- `description`: one line, e.g. `Narrative reading order for <PR title>`
- `favicon`: `📖`

The layout is fixed by the renderer, so this is a minimal-investment redeploy of a deterministic template — no design work is needed beyond the Artifact tool's own preconditions.

## Step 4: Return the link

Report the Artifact URL. It's private to the user's claude.ai account and shareable from there; the link is tappable on a phone, which suits driving a session over `/rc`.

To revise a published narrative, redeploy in place rather than minting a new URL: pass the same `file_path` for a same-session update, or the artifact's `url` for one published in an earlier session.
