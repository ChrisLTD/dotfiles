#!/usr/bin/env bash
# Expose a local port over Tailscale (tailnet-private) and print the URL.
# Uses HTTPS when the tailnet can provision certs; falls back to plain HTTP
# on port 80 otherwise (e.g. Headscale, which has no cert API).
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

read -r dnsname certs < <(
  tailscale status --json | node -e '
    let s = "";
    process.stdin.on("data", d => (s += d)).on("end", () => {
      const j = JSON.parse(s);
      const name = ((j.Self && j.Self.DNSName) || "").replace(/\.$/, "");
      const certs = Array.isArray(j.CertDomains) && j.CertDomains.length ? "yes" : "no";
      process.stdout.write(`${name} ${certs}\n`);
    });
  '
)

if [ -z "$dnsname" ]; then
  echo "could not resolve tailnet DNS name (is 'tailscale up' done and MagicDNS on?)" >&2
  exit 1
fi

# Re-running with the same port is idempotent; a new port replaces the mount.
if [ "$certs" = "yes" ]; then
  tailscale serve --bg "$port" >/dev/null
  echo "https://${dnsname}"
else
  tailscale serve --bg --http=80 "$port" >/dev/null 2>&1
  echo "http://${dnsname}"
fi
