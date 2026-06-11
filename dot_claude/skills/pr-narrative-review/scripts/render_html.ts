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
 * Syntax highlighting is optional: if `highlight.js` resolves from the working
 * directory (npm i -D highlight.js), code is highlighted; otherwise it renders
 * as plain escaped <pre>. The output HTML has no network dependencies.
 *
 * Input schema (narrative.json):
 * {
 *   "title": "PR title",
 *   "pr_url": "https://github.com/... (optional)",
 *   "entry_point": "Why the story starts where it does.",
 *   "shape": "6 files, ~76 lines. One sentence on the architecture.",
 *   "chapters": [
 *     {
 *       "title": "Chapter title",
 *       "prose": "Markdown-lite: paragraphs, `inline code`, **bold**, *em*.",
 *       "concerns": ["Optional per-chapter scrutiny bullets."],
 *       "blocks": [
 *         {
 *           "path": "src/lib/schemas.ts",
 *           "start": 12, "end": 23,
 *           "status": "added | modified | moved | deleted | context",
 *           "language": "ts",
 *           "code": "post-change code...",
 *           "note": "optional caption under the block"
 *         }
 *       ]
 *     }
 *   ],
 *   "appendix": [{ "file": "package-lock.json", "change": "Lockfile churn" }]
 * }
 *
 * The jump list (quickfix format) is generated automatically from chapters.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";
import { parseArgs } from "node:util";

type Status = "added" | "modified" | "moved" | "deleted" | "context";

interface Block {
  path: string;
  start?: number;
  end?: number;
  status?: Status;
  language?: string;
  code?: string;
  note?: string;
}

interface Chapter {
  title: string;
  prose?: string;
  concerns?: string[];
  blocks?: Block[];
}

interface Narrative {
  title?: string;
  pr_url?: string;
  entry_point?: string;
  shape?: string;
  chapters?: Chapter[];
  appendix?: { file: string; change: string }[];
}

// ---------------------------------------------------------------- highlighting

type Highlighter = (code: string, language: string) => string | null;

async function loadHighlighter(): Promise<Highlighter> {
  try {
    // Resolve from the working directory, not the script's own directory —
    // this script lives in ~/.claude/skills/, but highlight.js is installed
    // in the project being reviewed.
    const requireFromCwd = createRequire(join(process.cwd(), "package.json"));
    const mod = requireFromCwd("highlight.js");
    const hljs = (mod.default ?? mod) as typeof import("highlight.js").default;
    const aliases: Record<string, string> = { tsx: "typescript", jsx: "javascript" };
    return (code, language) => {
      const lang = aliases[language] ?? language;
      try {
        if (lang && hljs.getLanguage(lang)) {
          return hljs.highlight(code, { language: lang }).value;
        }
        return hljs.highlightAuto(code).value;
      } catch {
        return null;
      }
    };
  } catch {
    return () => null;
  }
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
function proseToHtml(text: string): string {
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

function renderBlock(b: Block, hl: Highlighter): string {
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
  const highlighted = hl(b.code ?? "", b.language ?? "");
  const codeHtml =
    highlighted !== null
      ? `<pre class="hl">${highlighted}</pre>`
      : `<pre class="plain">${esc(b.code ?? "")}</pre>`;
  const jump = `${b.path}:${start ?? 1}`;
  return `
<figure class="code-block" data-status="${esc(status)}">
  <figcaption>
    <button class="ref" title="Copy ${esc(jump)}" data-jump="${esc(jump)}">${ref}</button>
    <span class="badge badge-${esc(status)}">${esc(status)}</span>
  </figcaption>
  ${codeHtml}
  ${note}
</figure>`;
}

function renderChapter(i: number, ch: Chapter, total: number, hl: Highlighter): string {
  const blocks = (ch.blocks ?? []).map((b) => renderBlock(b, hl)).join("\n");
  const concerns = ch.concerns?.length
    ? `
<aside class="concerns">
  <h3>Worth scrutinizing</h3>
  <ul>${ch.concerns.map((c) => `<li>${proseToHtml(c)}</li>`).join("\n")}</ul>
</aside>`
    : "";
  return `
<section class="chapter" id="ch-${i}" data-index="${i}">
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

function render(data: Narrative, hl: Highlighter): string {
  const chapters = data.chapters ?? [];
  const total = chapters.length;
  const chaptersHtml = chapters
    .map((ch, i) => renderChapter(i + 1, ch, total, hl))
    .join("\n");
  const dots = chapters
    .map(
      (ch, i) =>
        `<a href='#ch-${i + 1}' class='dot' data-index='${i + 1}' title='${esc(ch.title)}'><span>${i + 1}</span></a>`,
    )
    .join("\n");
  const appendixRows = (data.appendix ?? [])
    .map(
      (a) =>
        `<tr><td><code>${esc(a.file)}</code></td><td>${esc(a.change)}</td></tr>`,
    )
    .join("\n");
  const appendix = appendixRows
    ? `
<section class="endmatter">
  <div class="endmatter-inner">
    <h2>Appendix: mechanical changes</h2>
    <table><thead><tr><th>File</th><th>Change</th></tr></thead><tbody>${appendixRows}</tbody></table>
  </div>
</section>`
    : "";
  const jump = buildJumpList(chapters);
  const title = esc(data.title ?? "PR narrative");
  const prLink = data.pr_url
    ? `<a class='pr-link' href='${esc(data.pr_url)}'>View PR ↗</a>`
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

header.masthead { display: grid; grid-template-columns: 55% 45%; min-height: 38vh; }
.masthead .m-left {
  background: var(--terminal); color: var(--code-fg);
  padding: 3rem 2.5rem; display: flex; flex-direction: column; justify-content: flex-end;
  font-family: var(--mono); font-size: 0.85rem; line-height: 1.6;
}
.masthead .m-left .shape { color: #98A4B0; max-width: 38ch; }
.masthead .m-left .kbd-hint { margin-top: 1.2rem; color: #6B7684; font-size: 0.75rem; }
.masthead .m-left kbd { border: 1px solid #3A434E; border-radius: 3px; padding: 0 5px; font-family: var(--mono); }
.masthead .m-right {
  padding: 3rem 3rem 3rem 2.8rem; display: flex; flex-direction: column; justify-content: flex-end;
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

.endmatter { border-top: 1px solid var(--paper-edge); padding: 3rem 0; }
.endmatter-inner { max-width: 760px; margin: 0 auto; padding: 0 2rem; }
.endmatter h2 { font-size: 1.25rem; margin-bottom: 0.9rem; }
.endmatter table { border-collapse: collapse; width: 100%; font-size: 0.92rem; }
.endmatter th { font-family: var(--sans); font-size: 0.7rem; letter-spacing: 0.1em; text-transform: uppercase; text-align: left; color: #6B7280; padding: 0.4rem 0.8rem 0.4rem 0; border-bottom: 1px solid var(--paper-edge); }
.endmatter td { padding: 0.5rem 0.8rem 0.5rem 0; border-bottom: 1px solid var(--paper-edge); }
.endmatter td code { font-family: var(--mono); font-size: 0.82em; }
.jump-help { font-size: 0.88rem; color: #5A6170; margin-bottom: 0.8rem; }
pre.jumplist { font-family: var(--mono); font-size: 0.8rem; line-height: 1.6; background: var(--terminal); color: var(--code-fg); padding: 1rem 1.2rem; border-radius: 4px; overflow-x: auto; }
.copy-jump { margin-top: 0.7rem; font-family: var(--sans); font-size: 0.78rem; background: var(--accent); color: #fff; border: none; padding: 0.45rem 0.9rem; border-radius: 4px; cursor: pointer; }
.copy-jump.copied { background: var(--added); }

@media (max-width: 880px) {
  header.masthead, .chapter { grid-template-columns: 1fr; }
  .pane-code { position: static; max-height: none; order: 2; padding: 1.5rem 1.2rem; }
  .pane-prose { order: 1; padding: 1.8rem 1.4rem; }
  .masthead .m-left { order: 2; padding: 1.5rem 1.4rem; min-height: 0; }
  .masthead .m-right { order: 1; padding: 2rem 1.4rem; }
  .chapter { min-height: 0; }
  nav.dots { display: none; }
  main { scroll-snap-type: none; }
}
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
</style>
</head>
<body>
<div class="progress" id="progress"></div>
<header class="masthead">
  <div class="m-left">
    <div class="shape">${esc(data.shape ?? "")}</div>
    <div class="kbd-hint"><kbd>j</kbd>/<kbd>k</kbd> or <kbd>←</kbd>/<kbd>→</kbd> flip chapters · click a reference to copy <span style="font-family:var(--mono)">path:line</span></div>
  </div>
  <div class="m-right">
    <div class="eyebrow">Narrative review</div>
    <h1>${title}</h1>
    <div class="entry-point"><strong>Entry point.</strong> ${esc(data.entry_point ?? "")}</div>
    ${prLink}
  </div>
</header>
<nav class="dots">${dots}</nav>
<main id="main">
${chaptersHtml}
${appendix}
<section class="endmatter">
  <div class="endmatter-inner">
    <h2>Jump list</h2>
    <p class="jump-help">Quickfix format — save and <code>:cfile</code> it to walk the PR in your editor.</p>
    <pre class="jumplist" id="jumplist">${esc(jump)}</pre>
    <button class="copy-jump" data-copy="jumplist">Copy jump list</button>
  </div>
</section>
</main>
<script>
(function () {
  var chapters = Array.prototype.slice.call(document.querySelectorAll(".chapter"));
  var dots = Array.prototype.slice.call(document.querySelectorAll(".dot"));
  var current = 0;

  function go(i) {
    if (i < 0 || i >= chapters.length) return;
    chapters[i].scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
  }

  document.addEventListener("keydown", function (e) {
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
    if (e.key === "j" || e.key === "ArrowRight") { e.preventDefault(); go(current + 1); }
    if (e.key === "k" || e.key === "ArrowLeft") { e.preventDefault(); go(current - 1); }
  });

  var obs = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (en.isIntersecting) {
        current = parseInt(en.target.dataset.index, 10) - 1;
        dots.forEach(function (d, di) { d.classList.toggle("active", di === current); });
      }
    });
  }, { threshold: 0.5 });
  chapters.forEach(function (c) { obs.observe(c); });

  window.addEventListener("scroll", function () {
    var h = document.documentElement;
    var pct = (h.scrollTop) / (h.scrollHeight - h.clientHeight) * 100;
    document.getElementById("progress").style.width = pct + "%";
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
  const hl = await loadHighlighter();
  const out = values.output ?? input.replace(/\.json$/, "") + ".html";
  writeFileSync(out, render(data, hl));
  if (hl("const x = 1", "ts") === null) {
    console.error(
      "note: highlight.js not found; code rendered without highlighting (npm i -D highlight.js to enable)",
    );
  }
  console.log(`wrote ${out}`);
}

main();
