#!/usr/bin/env bash
# Expose a local port over Tailscale (private tailnet HTTPS) and print the URL.
# Usage: expose.sh <port>
set -euo pipefail

port="${1:-}"
if [ -z "$port" ]; then
  echo "usage: expose.sh <port>" >&2
  exit 2
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "tailscale not found on PATH" >&2
  exit 1
fi

# Map https://<node>/ -> localhost:<port>. Re-running with the same port is idempotent.
tailscale serve --bg "$port" >/dev/null

# Resolve this node's DNS name from tailscale status (avoids a jq dependency).
dnsname="$(
  tailscale status --json | node -e '
    let s = "";
    process.stdin.on("data", d => (s += d)).on("end", () => {
      const j = JSON.parse(s);
      const name = (j.Self && j.Self.DNSName) || "";
      process.stdout.write(name.replace(/\.$/, ""));
    });
  '
)"

if [ -z "$dnsname" ]; then
  echo "could not resolve tailnet DNS name (is 'tailscale up' done and MagicDNS on?)" >&2
  exit 1
fi

echo "https://${dnsname}"
