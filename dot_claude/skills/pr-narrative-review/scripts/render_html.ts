#!/usr/bin/env node
/**
 * Render a PR narrative (narrative.json) into a self-contained two-pane HTML reader.
 *
 * Usage:
 *   node render_html.ts narrative.json -o pr-123-narrative.html
 *
 * Requires Node >= 22.18 / 23.6 (native TypeScript type-stripping).
 * On older Node: npx tsx render_html.ts narrative.json
 *
 * Syntax highlighting happens in the browser via highlight.js from cdnjs
 * (integrity-pinned). No local install needed; offline viewing degrades
 * gracefully to plain unhighlighted code.
 *
 * Input schema (narrative.json):
 * {
 *   "title": "PR title",
 *   "pr_url": "https://github.com/... (optional)",
 *   "branch": "feature/foo (optional head branch name)",
 *   "entry_point": "Why the story starts where it does.",
 *   "shape": "6 files, ~76 lines. One sentence on the architecture.",
 *   "chapters": [
 *     {
 *       "title": "Chapter title",
 *       "prose": "A string (paragraphs separated by blank lines) or an array of paragraph strings. Markdown-lite: `inline code`, **bold**, *em*.",
 *       "concerns": ["Optional per-chapter scrutiny bullets."],
 *       "blocks": [
 *         {
 *           "path": "src/lib/schemas.ts",
 *           "start": 12, "end": 23,
 *           "status": "added | modified | moved | deleted | context",
 *           "language": "ts",
 *           "code": "post-change code...",
 *           "changed_lines": [3, 4],
 *           "diff": "@@ -12,4 +12,5 @@ ... (optional trimmed unified hunk)",
 *           "note": "optional caption under the block"
 *         }
 *       ]
 *     }
 *   ],
 *   "appendix": [{ "file": "package-lock.json", "change": "Lockfile churn" }]
 * }
 *
 * The jump list (quickfix format) is generated automatically from chapters.
 *
 * `changed_lines` (optional, for modified blocks): 1-based line offsets within
 * `code` that differ from the base ref. They render as tinted stripes behind
 * the code so the reader sees where the change is inside surrounding context.
 *
 * `diff` (optional, for modified blocks worth scrutiny): the unified hunk for
 * the shown range, taken from git and trimmed. Adds a "view diff" toggle to
 * the block; the after-view stays the default.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { parseArgs } from "node:util";

type Status = "added" | "modified" | "moved" | "deleted" | "context";

interface Block {
  path: string;
  start?: number;
  end?: number;
  status?: Status;
  language?: string;
  code?: string;
  changed_lines?: number[];
  diff?: string;
  note?: string;
}

interface Chapter {
  title: string;
  prose?: string | string[];
  concerns?: string[];
  blocks?: Block[];
}

interface Narrative {
  title?: string;
  pr_url?: string;
  branch?: string;
  entry_point?: string;
  shape?: string;
  chapters?: Chapter[];
  appendix?: { file: string; change: string }[];
}

// ---------------------------------------------------------------- highlighting

// Highlighting runs in the browser via the cdnjs bundle loaded at the bottom
// of the page. Languages outside the common bundle (dockerfile, elixir, ...)
// get an extra per-language script tag, generated from the block languages.
const CDN_BASE = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1";
const HLJS_CDN = `${CDN_BASE}/highlight.min.js`;
const HLJS_SRI = "sha512-EBLzUL8XLl+va/zAsmXwS7Z2B1F9HUHkZwyS/VKwh3S7T/U0nF4BaU29EP/ZSf6zgiIxYAnKLu6bJ8dqpmX5uw==";

// Names and aliases the common bundle registers (extracted from highlight.min.js 11.11.1).
const BUNDLED_LANGS = new Set(["atom","bash","c","c#","c++","cc","cjs","console","cpp","cs","csharp","css","cts","cxx","diff","gemspec","go","golang","gql","graphql","gyp","h","h++","hh","hpp","html","hxx","ini","ipython","irb","java","javascript","js","json","jsonc","jsp","jsx","kotlin","kt","kts","less","lua","mak","make","makefile","markdown","md","mjs","mk","mkd","mkdown","mm","mts","obj-c","obj-c++","objc","objective-c++","objectivec","patch","perl","php","php-template","pl","plaintext","plist","pluto","pm","podspec","py","pycon","python","python-repl","r","rb","rs","rss","ruby","rust","scss","sh","shell","shellsession","sql","svg","swift","text","thor","toml","ts","tsx","txt","typescript","vb","vbnet","wasm","wsf","xhtml","xjb","xml","xsd","xsl","yaml","yml","zsh"]);

/** Script tags for block languages the common bundle doesn't cover. */
function extraLanguageTags(chapters: Chapter[]): string {
  const extra = new Set<string>();
  for (const ch of chapters) {
    for (const b of ch.blocks ?? []) {
      const lang = b.language?.toLowerCase();
      // Strict charset check doubles as URL sanitization.
      if (lang && !BUNDLED_LANGS.has(lang) && /^[a-z0-9-]+$/.test(lang)) extra.add(lang);
    }
  }
  return [...extra]
    .sort()
    .map((l) => `<script src="${CDN_BASE}/languages/${l}.min.js" crossorigin="anonymous" referrerpolicy="no-referrer"></script>`)
    .join("\n");
}

// ---------------------------------------------------------------- text helpers

function esc(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** Minimal markdown: paragraphs, `inline code`, **bold**, *em*. Everything else escaped. */
function proseToHtml(input: string | string[]): string {
  const text = Array.isArray(input) ? input.join("\n\n") : input;
  return text
    .trim()
    .split(/\n\s*\n/)
    .map((para) => {
      let p = esc(para.trim());
      p = p.replace(/`([^`]+)`/g, "<code>$1</code>");
      p = p.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
      p = p.replace(/(?<!\*)\*([^*\n]+)\*(?!\*)/g, "<em>$1</em>");
      return `<p>${p}</p>`;
    })
    .join("\n");
}

// ---------------------------------------------------------------- renderers

function renderBlock(b: Block): string {
  const path = esc(b.path);
  const { start, end } = b;
  const ref =
    start && end && start !== end
      ? `${path}:${start}-${end}`
      : start
        ? `${path}:${start}`
        : path;
  const status = b.status ?? "modified";
  const note = b.note ? `<div class="block-note">${proseToHtml(b.note)}</div>` : "";
  const lang = b.language?.toLowerCase() ?? "";
  const langClass = lang ? ` class="language-${esc(lang)}"` : "";
  // Tint stripes are positioned siblings, not markup inside <code> — hljs
  // replaces the code element's innerHTML at highlight time and would destroy
  // per-line spans. Offsets must match pre.hl's font-size × line-height
  // (0.8rem × 1.55 = 1.24rem per line, 0.2rem top padding) in the CSS below.
  const lineCount = (b.code ?? "").split("\n").length;
  const tints = (b.changed_lines ?? [])
    .filter((n) => Number.isInteger(n) && n >= 1 && n <= lineCount)
    .map((n) => `<i class="line-tint" style="top: calc(0.2rem + ${((n - 1) * 1.24).toFixed(2)}rem)"></i>`)
    .join("");
  const codeHtml = `<div class="code-wrap">${tints ? `<div class="line-tints" aria-hidden="true">${tints}</div>` : ""}<pre class="hl"><code${langClass}>${esc(b.code ?? "")}</code></pre></div>`;
  const diffView = b.diff
    ? `<pre class="hl diff-view"><code class="language-diff">${esc(b.diff)}</code></pre>`
    : "";
  const toggle = b.diff
    ? `<button class="view-toggle" role="switch" aria-checked="false" title="Toggle after/diff view"><span class="vt-opt active">after</span><span class="vt-opt">diff</span></button>`
    : "";
  const jump = `${b.path}:${start ?? 1}`;
  return `
<figure class="code-block" data-status="${esc(status)}">
  <figcaption>
    <button class="ref" title="Copy ${esc(jump)}" data-jump="${esc(jump)}">${ref}</button>
    <span class="badge badge-${esc(status)}">${esc(status)}</span>
    ${toggle}
  </figcaption>
  ${codeHtml}
  ${diffView}
  ${note}
</figure>`;
}

function renderChapter(i: number, ch: Chapter, total: number): string {
  const blocks = (ch.blocks ?? []).map((b) => renderBlock(b)).join("\n");
  const concerns = ch.concerns?.length
    ? `
<aside class="concerns">
  <h3>Worth scrutinizing</h3>
  <ul>${ch.concerns.map((c) => `<li>${proseToHtml(c)}</li>`).join("\n")}</ul>
</aside>`
    : "";
  return `
<section class="chapter" id="ch-${i}" data-slide="${i}">
  <div class="pane pane-code">${blocks || "<p class='no-code'>No code in this chapter.</p>"}</div>
  <div class="pane pane-prose">
    <header class="chapter-head">
      <span class="ch-num">${i} / ${total}</span>
      <h2>${esc(ch.title)}</h2>
    </header>
    ${proseToHtml(ch.prose ?? "")}
    ${concerns}
  </div>
</section>`;
}

function buildJumpList(chapters: Chapter[]): string {
  const lines: string[] = [];
  chapters.forEach((ch, idx) => {
    const b = ch.blocks?.[0];
    if (!b) return;
    lines.push(`${b.path}:${b.start ?? 1}: ${idx + 1}. ${ch.title}`);
  });
  return lines.join("\n");
}

// highlight.js token classes mapped to the page's dark-pane palette.
const HLJS_CSS = `
.hl .hljs-keyword, .hl .hljs-selector-tag, .hl .hljs-tag { color: #8FAFD4; }
.hl .hljs-string, .hl .hljs-regexp, .hl .hljs-addition { color: #A8C0A0; }
.hl .hljs-comment, .hl .hljs-quote { color: #6B7684; font-style: italic; }
.hl .hljs-title, .hl .hljs-title.function_, .hl .hljs-function { color: #DCC8A0; }
.hl .hljs-title.class_, .hl .hljs-type, .hl .hljs-class { color: #C7B2D6; }
.hl .hljs-built_in, .hl .hljs-builtin-name { color: #9BC4C9; }
.hl .hljs-number, .hl .hljs-literal, .hl .hljs-deletion { color: #CFA8A8; }
.hl .hljs-attr, .hl .hljs-attribute, .hl .hljs-property, .hl .hljs-params { color: #DCC8A0; }
.hl .hljs-operator, .hl .hljs-punctuation { color: #98A4B0; }
.hl .hljs-variable, .hl .hljs-name { color: #D6DEE6; }
`;

function render(data: Narrative): string {
  const chapters = data.chapters ?? [];
  const total = chapters.length;
  const chaptersHtml = chapters
    .map((ch, i) => renderChapter(i + 1, ch, total))
    .join("\n");
  const appendixRows = (data.appendix ?? [])
    .map(
      (a) =>
        `<tr><td><code>${esc(a.file)}</code></td><td>${esc(a.change)}</td></tr>`,
    )
    .join("\n");
  // Slides: 0 = masthead, 1..N = chapters, end matter (appendix + jump list) last.
  const endSlide = total + 1;
  const appendixHtml = appendixRows
    ? `
    <h2>Appendix: mechanical changes</h2>
    <table><thead><tr><th>File</th><th>Change</th></tr></thead><tbody>${appendixRows}</tbody></table>`
    : "";
  const dotEntries = [
    { href: "#top", label: "⌂", title: "Top" },
    ...chapters.map((ch, i) => ({ href: `#ch-${i + 1}`, label: String(i + 1), title: ch.title })),
    { href: "#end", label: "J", title: appendixRows ? "Appendix & jump list" : "Jump list" },
  ];
  const dots = dotEntries
    .map(
      (d, i) =>
        `<a href='${d.href}' class='dot' data-slide='${i}' title='${esc(d.title)}'><span>${esc(d.label)}</span></a>`,
    )
    .join("\n");
  const jump = buildJumpList(chapters);
  const title = esc(data.title ?? "PR narrative");
  const prLink = data.pr_url
    ? `<a class='pr-link' href='${esc(data.pr_url)}'>View PR ↗</a>`
    : "";
  const branchChip = data.branch
    ? `<code class="branch-chip">${esc(data.branch)}</code>`
    : "";
  const endLinkItems = [
    ...(branchChip ? [branchChip] : []),
    ...(data.pr_url ? [`<a href="${esc(data.pr_url)}">View PR ↗</a>`] : []),
  ];
  const endLinks = endLinkItems.length
    ? `<p class="end-links">${endLinkItems.join("\n")}</p>`
    : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — narrative review</title>
<style>
:root {
  --ink: #1E2430;
  --paper: #F7F6F2;
  --paper-edge: #E9E7DF;
  --terminal: #14171A;
  --terminal-edge: #232930;
  --code-fg: #D6DEE6;
  --accent: #34507A;
  --accent-soft: #8FAFD4;
  --rust: #9C4A2F;
  --added: #4E7A52;
  --deleted: #9C3D3D;
  --modified: #8A6D2F;
  --mono: ui-monospace, "JetBrains Mono", "Cascadia Code", Menlo, Consolas, monospace;
  --serif: Charter, "Bitstream Charter", "Sitka Text", Cambria, Georgia, serif;
  --sans: -apple-system, "Segoe UI", system-ui, sans-serif;
}
* { box-sizing: border-box; margin: 0; }
html { scroll-behavior: smooth; }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } }
body { font-family: var(--serif); color: var(--ink); background: var(--paper); }

.progress { position: fixed; top: 0; left: 0; height: 3px; background: var(--accent); width: 0; z-index: 30; transition: width 120ms linear; }

header.masthead { display: grid; grid-template-columns: 55% 45%; min-height: 100vh; }
.masthead .m-left {
  background: var(--terminal); color: var(--code-fg);
  padding: 3rem 2.5rem; display: flex; flex-direction: column; justify-content: flex-start;
  font-family: var(--mono); font-size: 0.85rem; line-height: 1.6;
}
.masthead .m-left .shape { color: #98A4B0; max-width: 38ch; }
.masthead .m-left .kbd-hint { margin-top: 1.2rem; color: #6B7684; font-size: 0.75rem; }
.masthead .m-left kbd { border: 1px solid #3A434E; border-radius: 3px; padding: 0 5px; font-family: var(--mono); }
.masthead .m-right {
  padding: 3rem 3rem 3rem 2.8rem; display: flex; flex-direction: column; justify-content: flex-start;
  border-bottom: 1px solid var(--paper-edge);
}
.eyebrow { font-family: var(--sans); font-size: 0.7rem; letter-spacing: 0.14em; text-transform: uppercase; color: var(--accent); margin-bottom: 0.8rem; }
h1 { font-size: clamp(1.5rem, 3.2vw, 2.4rem); line-height: 1.15; font-weight: 700; margin-bottom: 1rem; }
.entry-point { font-size: 1.02rem; line-height: 1.55; color: #3D4452; max-width: 52ch; }
.entry-point strong { color: var(--accent); }
.pr-link { font-family: var(--sans); font-size: 0.8rem; color: var(--accent); text-decoration: none; margin-top: 1rem; display: inline-block; }

main { scroll-snap-type: y proximity; }
.chapter { display: grid; grid-template-columns: 55% 45%; min-height: 100vh; scroll-snap-align: start; }
.pane-code {
  background: var(--terminal); border-top: 1px solid var(--terminal-edge);
  padding: 2.2rem 2.5rem; overflow-y: auto; max-height: 100vh;
  position: sticky; top: 0;
}
.pane-prose {
  padding: 2.6rem 3rem 2.6rem 2.8rem; border-top: 1px solid var(--paper-edge);
  font-size: 1.02rem; line-height: 1.62;
}
.pane-prose p { margin-bottom: 1rem; max-width: 56ch; }
.pane-prose code { font-family: var(--mono); font-size: 0.84em; background: #ECEAE2; padding: 1px 5px; border-radius: 3px; }
.chapter-head { margin-bottom: 1.4rem; }
.ch-num { font-family: var(--mono); font-size: 0.72rem; color: var(--accent); letter-spacing: 0.06em; }
.chapter-head h2 { font-size: 1.45rem; line-height: 1.2; margin-top: 0.35rem; }

.code-block { margin-bottom: 1.8rem; }
.code-block figcaption {
  display: flex; align-items: center; gap: 0.7rem; margin-bottom: 0.5rem;
  font-family: var(--mono); font-size: 0.74rem;
}
.ref {
  background: none; border: none; color: var(--accent-soft); font-family: var(--mono);
  font-size: 0.74rem; cursor: pointer; padding: 2px 0; border-bottom: 1px dashed #3A434E;
}
.ref:hover, .ref:focus-visible { color: #C9DCF2; }
.ref.copied::after { content: " copied"; color: #A8C0A0; }
.badge { font-family: var(--sans); font-size: 0.62rem; letter-spacing: 0.1em; text-transform: uppercase; padding: 2px 7px; border-radius: 9px; color: #fff; }
.badge-added { background: var(--added); }
.badge-modified { background: var(--modified); }
.badge-deleted { background: var(--deleted); }
.badge-moved { background: var(--accent); }
.badge-context { background: #4A5360; }
pre.hl, pre.plain {
  font-family: var(--mono); font-size: 0.8rem; line-height: 1.55; color: var(--code-fg);
  overflow-x: auto; padding: 0.2rem 0 0.2rem 0.9rem; border-left: 2px solid #2C333C;
  white-space: pre; tab-size: 2;
}
.code-block[data-status="added"] pre { border-left-color: var(--added); }
.code-block[data-status="deleted"] pre { border-left-color: var(--deleted); }
.code-block[data-status="modified"] pre { border-left-color: var(--modified); }
.view-toggle { margin-left: auto; display: inline-flex; gap: 2px; background: #20262D; border: 1px solid #3A434E; border-radius: 9px; padding: 2px; cursor: pointer; font-family: var(--sans); font-size: 0.6rem; letter-spacing: 0.08em; text-transform: uppercase; }
.view-toggle:hover, .view-toggle:focus-visible { border-color: #5A6678; }
.view-toggle .vt-opt { padding: 1px 7px; border-radius: 7px; color: #98A4B0; transition: background 120ms, color 120ms; }
.view-toggle .vt-opt.active { background: var(--accent); color: #fff; }
.code-block.show-diff .code-wrap { display: none; }
.code-block:not(.show-diff) .diff-view { display: none; }
.code-wrap { position: relative; }
.line-tints { position: absolute; inset: 0; pointer-events: none; }
/* Stripe height/offsets are coupled to pre.hl font-size (0.8rem) and line-height (1.55). */
.line-tint { position: absolute; left: 0; right: 0; height: 1.24rem; background: rgba(138, 109, 47, 0.22); }
.block-note { font-family: var(--sans); font-size: 0.76rem; color: #98A4B0; margin-top: 0.5rem; max-width: 60ch; }
.block-note p { margin: 0; }
.no-code { color: #6B7684; font-family: var(--mono); font-size: 0.8rem; }
${HLJS_CSS}
.concerns {
  margin-top: 1.6rem; border: 1px solid #D9C5BB; border-left: 3px solid var(--rust);
  background: #F4EEE9; padding: 1rem 1.2rem; border-radius: 0 4px 4px 0;
}
.concerns h3 { font-family: var(--sans); font-size: 0.7rem; letter-spacing: 0.12em; text-transform: uppercase; color: var(--rust); margin-bottom: 0.55rem; }
.concerns ul { padding-left: 1.1rem; }
.concerns li { font-size: 0.92rem; line-height: 1.5; margin-bottom: 0.45rem; }
.concerns li p { display: inline; }

nav.dots {
  position: fixed; right: 0.9rem; top: 50%; transform: translateY(-50%);
  display: flex; flex-direction: column; gap: 0.45rem; z-index: 20;
}
.dot {
  width: 22px; height: 22px; border-radius: 50%; display: grid; place-items: center;
  font-family: var(--mono); font-size: 0.6rem; color: #8B8F98; text-decoration: none;
  border: 1px solid #C9C7BF; background: rgba(247,246,242,0.85);
}
.dot.active { background: var(--accent); border-color: var(--accent); color: #fff; }

.endmatter { border-top: 1px solid var(--paper-edge); padding: 2.6rem 0 3rem; min-height: 100vh; scroll-snap-align: start; }
.endmatter-inner { max-width: 760px; margin: 0 auto; padding: 0 2rem; width: 100%; }
.endmatter h2 { font-size: 1.25rem; margin-bottom: 0.9rem; }
.endmatter table { border-collapse: collapse; width: 100%; font-size: 0.92rem; margin-bottom: 2.5rem; }
.endmatter th { font-family: var(--sans); font-size: 0.7rem; letter-spacing: 0.1em; text-transform: uppercase; text-align: left; color: #6B7280; padding: 0.4rem 0.8rem 0.4rem 0; border-bottom: 1px solid var(--paper-edge); }
.endmatter td { padding: 0.5rem 0.8rem 0.5rem 0; border-bottom: 1px solid var(--paper-edge); }
.endmatter td code { font-family: var(--mono); font-size: 0.82em; }
.jump-help { font-size: 0.88rem; color: #5A6170; margin-bottom: 0.8rem; }
pre.jumplist { font-family: var(--mono); font-size: 0.8rem; line-height: 1.6; background: var(--terminal); color: var(--code-fg); padding: 1rem 1.2rem; border-radius: 4px; overflow-x: auto; }
.copy-jump { margin-top: 0.7rem; font-family: var(--sans); font-size: 0.78rem; background: var(--accent); color: #fff; border: none; padding: 0.45rem 0.9rem; border-radius: 4px; cursor: pointer; }
.copy-jump.copied { background: var(--added); }
.end-links { margin-top: 2.2rem; padding-top: 1.2rem; border-top: 1px solid var(--paper-edge); font-family: var(--sans); font-size: 0.85rem; }
.end-links a { color: var(--accent); text-decoration: none; margin-right: 1.4rem; }
.end-links a:hover { text-decoration: underline; }
.branch-chip { font-family: var(--mono); font-size: 0.78rem; color: var(--accent); background: #ECEAE2; padding: 2px 8px; border-radius: 3px; }
.end-links .branch-chip { margin-right: 1.4rem; }
.masthead-branch { margin-bottom: 1rem; }

@media (max-width: 880px) {
  header.masthead, .chapter { grid-template-columns: 1fr; }
  .pane-code { position: static; max-height: none; order: 2; padding: 1.5rem 1.2rem; }
  .pane-prose { order: 1; padding: 1.8rem 1.4rem; }
  .masthead .m-left { order: 2; padding: 1.5rem 1.4rem; min-height: 0; }
  .masthead .m-right { order: 1; padding: 2rem 1.4rem; }
  header.masthead, .chapter, .endmatter { min-height: 0; }
  nav.dots { display: none; }
  main { scroll-snap-type: none; }
}
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
</style>
</head>
<body>
<div class="progress" id="progress"></div>
<header class="masthead" id="top" data-slide="0">
  <div class="m-left">
    <div class="shape">${esc(data.shape ?? "")}</div>
    <div class="kbd-hint"><kbd>j</kbd>/<kbd>k</kbd> or <kbd>↓</kbd>/<kbd>↑</kbd> flip slides · click a reference to copy <span style="font-family:var(--mono)">path:line</span></div>
  </div>
  <div class="m-right">
    <div class="eyebrow">Narrative review</div>
    <h1>${title}</h1>
    ${branchChip ? `<div class="masthead-branch">${branchChip}</div>` : ""}
    <div class="entry-point"><strong>Entry point.</strong> ${esc(data.entry_point ?? "")}</div>
    ${prLink}
  </div>
</header>
<nav class="dots">${dots}</nav>
<main id="main">
${chaptersHtml}
<section class="endmatter" id="end" data-slide="${endSlide}">
  <div class="endmatter-inner">${appendixHtml}
    <h2>Jump list</h2>
    <p class="jump-help">Quickfix format — copy, then <code>:cexpr @+</code> in Neovim to walk the PR in narrative order.</p>
    <pre class="jumplist" id="jumplist">${esc(jump)}</pre>
    <button class="copy-jump" data-copy="jumplist">Copy jump list</button>
    ${endLinks}
  </div>
</section>
</main>
<script src="${HLJS_CDN}" integrity="${HLJS_SRI}" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
${extraLanguageTags(chapters)}
<script>
(function () {
  if (window.hljs) window.hljs.highlightAll();
  var slides = Array.prototype.slice.call(document.querySelectorAll("[data-slide]")).filter(function (el) { return !el.classList.contains("dot"); });
  var dots = Array.prototype.slice.call(document.querySelectorAll(".dot"));

  // Derive the current slide from scroll position: the last slide whose top
  // is above the viewport's midline. Robust for slides taller or shorter
  // than the viewport, unlike intersection-ratio tracking.
  function currentIndex() {
    var probe = window.scrollY + window.innerHeight / 2;
    var idx = 0;
    for (var i = 0; i < slides.length; i++) {
      if (slides[i].offsetTop <= probe) idx = i;
    }
    return idx;
  }

  function go(i) {
    if (i < 0 || i >= slides.length) return;
    slides[i].scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
  }

  document.addEventListener("keydown", function (e) {
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
    if (e.key === "j" || e.key === "ArrowDown") { e.preventDefault(); go(currentIndex() + 1); }
    if (e.key === "k" || e.key === "ArrowUp") { e.preventDefault(); go(currentIndex() - 1); }
  });

  function syncDots() {
    var c = currentIndex();
    dots.forEach(function (d, di) { d.classList.toggle("active", di === c); });
  }
  syncDots();

  window.addEventListener("scroll", function () {
    var h = document.documentElement;
    var pct = (h.scrollTop) / (h.scrollHeight - h.clientHeight) * 100;
    document.getElementById("progress").style.width = pct + "%";
    syncDots();
  }, { passive: true });

  function copy(text, el, cls) {
    function done() { el.classList.add(cls); setTimeout(function () { el.classList.remove(cls); }, 1400); }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, done);
    } else {
      var ta = document.createElement("textarea");
      ta.value = text; document.body.appendChild(ta); ta.select();
      try { document.execCommand("copy"); } catch (e) {}
      document.body.removeChild(ta); done();
    }
  }
  document.querySelectorAll(".ref").forEach(function (btn) {
    btn.addEventListener("click", function () { copy(btn.dataset.jump, btn, "copied"); });
  });
  document.querySelectorAll(".view-toggle").forEach(function (btn) {
    var opts = btn.querySelectorAll(".vt-opt");
    btn.addEventListener("click", function () {
      var showDiff = btn.closest("figure").classList.toggle("show-diff");
      btn.setAttribute("aria-checked", showDiff ? "true" : "false");
      opts[0].classList.toggle("active", !showDiff);
      opts[1].classList.toggle("active", showDiff);
    });
  });
  var cj = document.querySelector(".copy-jump");
  if (cj) cj.addEventListener("click", function () {
    copy(document.getElementById("jumplist").textContent, cj, "copied");
  });
})();
</script>
</body>
</html>`;
}

// ---------------------------------------------------------------- main

async function main(): Promise<void> {
  const { values, positionals } = parseArgs({
    options: { output: { type: "string", short: "o" } },
    allowPositionals: true,
  });
  const input = positionals[0];
  if (!input) {
    console.error("usage: node render_html.ts narrative.json [-o out.html]");
    process.exit(1);
  }
  const data: Narrative = JSON.parse(readFileSync(input, "utf8"));
  const out = values.output ?? input.replace(/\.json$/, "") + ".html";
  writeFileSync(out, render(data));
  console.log(`wrote ${out}`);
}

main();
