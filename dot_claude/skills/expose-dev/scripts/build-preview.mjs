#!/usr/bin/env node
// Build a self-contained, theme-aware preview page for the expose-dev skill.
// Emits an HTML file (no external requests, per Artifact CSP) with a big tappable
// link and a scannable QR for a URL, and/or an embedded screenshot.
//
// Usage:
//   build-preview.mjs --url <url> [--title <t>] [--image <png>] --out <file.html>
//   build-preview.mjs --image <png> [--title <t>] --out <file.html>

import { execFileSync } from 'node:child_process';
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

function qrSvg(text) {
  try {
    // Quiet zone -m 2; qrencode picks the smallest fitting version.
    return execFileSync('qrencode', ['-t', 'SVG', '-m', '2', '-o', '-', text], {
      encoding: 'utf8',
    });
  } catch {
    console.error("qrencode not found — install it with: brew install qrencode");
    process.exit(1);
  }
}

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
    <code class="url">${esc(args.url)}</code>
    <div class="qr">${qrSvg(args.url)}</div>
    <p class="hint">Tap the button on your phone, or scan the QR from another screen.</p>`
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
  .url {
    display: block; margin: 0.9rem auto 0; word-break: break-all;
    font-size: 0.85rem; opacity: 0.7;
  }
  .qr {
    max-width: 240px; margin: 1.5rem auto 0;
    background: #fff; padding: 12px; border-radius: 12px;
  }
  .qr svg { width: 100%; height: auto; display: block; }
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
