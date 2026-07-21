---
name: expose-dev
description: >-
  Expose a locally running dev server to your phone or another device over
  Tailscale, or capture a screenshot, and hand back a tappable link plus a
  scannable QR as an Artifact. Use when driving a session from your phone via
  /rc and you want to preview the running app or a screenshot without typing
  URLs. Trigger on "expose the dev server", "get this on my phone", "preview on
  my phone", "tunnel the dev server", "put the app on my phone", or "screenshot
  to my phone". Mac only.
---

# expose-dev

Surface a local dev server (or a screenshot) to your phone / another device. Default
transport is **Tailscale** (private to your tailnet, stable URL, and it proxies to
`localhost`-only servers). The deliverable is an **Artifact** page with a big tappable link
and a QR code, so from a phone you tap and from a second screen you scan.

Scripts live in `~/.claude/skills/expose-dev/scripts/`. Invoke them with `bash` / `node`.

## Mode A — Live preview (default)

1. **Resolve the port.** Use the port the user gave. Otherwise probe common dev ports and
   use the first that answers:
   ```bash
   for p in 3000 3030 3333 5173 8080; do curl -sf -o /dev/null "http://localhost:$p" && echo "up:$p"; done
   ```
   If nothing answers, go to step 2.

2. **Ensure the server is running.** If this is the measured-app monorepo
   (`git remote get-url origin` matches `measured-fi/measured-app`), start/check it by
   invoking the **`dev-servers`** skill (do not reimplement its port map). In any other repo,
   report which port isn't answering and ask how to start it — don't guess a start command.

3. **Expose over Tailscale** and get the URL:
   ```bash
   bash ~/.claude/skills/expose-dev/scripts/expose.sh <port>
   ```
   Prints the `https://<machine>.<tailnet>.ts.net` URL. This proxies `localhost:<port>` over
   the tailnet, so it works even when the dev server binds only to `127.0.0.1`.

4. **Build the preview page and publish it.** `qrencode` is installed via the Brewfile
   (run `chezmoi apply` if it's missing). Then:
   ```bash
   node ~/.claude/skills/expose-dev/scripts/build-preview.mjs \
     --url "<url from step 3>" --title "<app name>:<port>" \
     --out "$SCRATCHPAD/expose-preview.html"
   ```
   (`$SCRATCHPAD` = the session scratchpad dir.) Then call the **Artifact** tool on that HTML
   file (favicon `📱`, a short title like "Dev preview"). Give the user the artifact link —
   they tap it on the phone; a QR is there for scanning from another screen.

5. **Teardown.** Tell the user how to stop serving when done:
   ```bash
   tailscale serve reset
   ```

## Mode B — Screenshot

- **measured-app:** invoke the **`pr-screenshots`** skill to capture via the Playwright
  harness. Deliver the PNG with `SendUserFile` (shows immediately in the phone session). To
  also give a persistent link, embed it in a page and publish it:
  ```bash
  node ~/.claude/skills/expose-dev/scripts/build-preview.mjs \
    --image "<png path>" --title "<what it shows>" --out "$SCRATCHPAD/shot.html"
  ```
  then call the Artifact tool on it.
- **Other repos:** capture with the Chrome MCP tools (navigate to `localhost:<port>`, then a
  `computer` screenshot) or `screencapture`, then deliver the same way.

## Going public (not the default)

Tailscale `serve` is **private** to your tailnet. Only when you need to hand a link to
someone *not* on your tailnet:
- `tailscale funnel <port>` — same node URL, but **public**. Say so before running it.
- `cloudflared tunnel --url http://localhost:<port>` or `ngrok http <port>` — public, and
  **not installed** here (would need `brew install`). Use only on explicit request.

## Gotchas

- `tailscale serve` HTTPS needs MagicDNS + HTTPS enabled for the tailnet. If it errors, fall
  back to binding the dev server to `0.0.0.0` and using `http://<tailnet-ip>:<port>`
  (`tailscale ip -4`).
- `serve` is private; `funnel` is public — never funnel silently.
- One port at a time: `serve` mounts at the node's HTTPS root, so exposing a second port
  replaces the first. Re-run `expose.sh` to switch back.
- Your machine must stay awake for the serve + dev server to stay reachable.
