#!/usr/bin/env node
// Build a self-contained, theme-aware preview page for the expose-dev skill.
// Emits an HTML file (no external requests, per Artifact CSP) with a big tappable
// link and a copyable URL, and/or an embedded screenshot.
//
// Usage:
//   build-preview.mjs --url <url> [--title <t>] [--image <png>] --out <file.html>
//   build-preview.mjs --image <png> [--title <t>] --out <file.html>

import { readFileSync, writeFileSync } from 'node:fs';

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) out[a.slice(2)] = argv[++i];
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
if (!args.out || (!args.url && !args.image)) {
  console.error('usage: build-preview.mjs --url <url> [--title <t>] [--image <png>] --out <file.html>');
  process.exit(2);
}

const esc = (s = '') =>
  String(s).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function imgDataUri(path) {
  const b64 = readFileSync(path).toString('base64');
  const ext = path.toLowerCase().endsWith('.jpg') || path.toLowerCase().endsWith('.jpeg')
    ? 'jpeg' : 'png';
  return `data:image/${ext};base64,${b64}`;
}

const title = args.title || (args.url ? 'Dev preview' : 'Screenshot');

const linkBlock = args.url
  ? `
    <a class="open" href="${esc(args.url)}">Open ${esc(title)}</a>
    <div class="urlrow">
      <code class="url" id="url">${esc(args.url)}</code>
      <button class="copy" id="copy">Copy</button>
    </div>
    <p class="hint">Tap the button to open, or copy the URL for another device.</p>
    <script>
      document.getElementById('copy').addEventListener('click', async () => {
        const url = document.getElementById('url').textContent;
        const btn = document.getElementById('copy');
        try {
          await navigator.clipboard.writeText(url);
          btn.textContent = 'Copied ✓';
        } catch {
          const range = document.createRange();
          range.selectNodeContents(document.getElementById('url'));
          getSelection().removeAllRanges();
          getSelection().addRange(range);
          btn.textContent = 'Select + copy';
        }
        setTimeout(() => (btn.textContent = 'Copy'), 2000);
      });
    </script>`
  : '';

const shotBlock = args.image
  ? `<img class="shot" alt="${esc(title)}" src="${imgDataUri(args.image)}" />`
  : '';

const html = `<div class="wrap">
  <h1>${esc(title)}</h1>
  ${linkBlock}
  ${shotBlock}
</div>
<style>
  :root { color-scheme: light dark; }
  .wrap {
    max-width: 640px; margin: 0 auto; padding: 2rem 1.25rem;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
    text-align: center;
  }
  h1 { font-size: 1.25rem; font-weight: 650; margin: 0 0 1.25rem; }
  .open {
    display: inline-block; padding: 0.85rem 1.5rem; border-radius: 12px;
    background: #2563eb; color: #fff; text-decoration: none; font-weight: 600;
    font-size: 1.05rem;
  }
  .open:active { transform: scale(0.98); }
  .urlrow {
    display: flex; align-items: center; justify-content: center; gap: 0.5rem;
    margin-top: 0.9rem; flex-wrap: wrap;
  }
  .url { word-break: break-all; font-size: 0.85rem; opacity: 0.7; }
  .copy {
    padding: 0.35rem 0.75rem; border-radius: 8px; border: 1px solid currentColor;
    background: transparent; color: inherit; font: inherit; font-size: 0.85rem;
    cursor: pointer; opacity: 0.8; flex-shrink: 0;
  }
  .copy:active { transform: scale(0.96); }
  .hint { font-size: 0.85rem; opacity: 0.6; margin-top: 1rem; }
  .shot {
    max-width: 100%; height: auto; margin-top: 1.25rem; border-radius: 12px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.18);
  }
  @media (prefers-color-scheme: dark) {
    body { background: #0b0d12; color: #e6e8ee; }
  }
  :root[data-theme="dark"] body { background: #0b0d12; color: #e6e8ee; }
  :root[data-theme="light"] body { background: #fff; color: #111; }
</style>`;

writeFileSync(args.out, html);
console.log(args.out);
