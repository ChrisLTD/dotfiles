---
name: dev-servers
description: Start, check, or stop local dev servers in the measured-app monorepo (measured-fi/measured-app) ONLY. Do not use in other projects.
---

# Measured app local dev servers

This skill applies ONLY to clones of the measured-app monorepo (measured-fi/measured-app). If unsure, check with `git remote get-url origin`; if the remote is a different repo, this skill does not apply.

| App      | Package                 | URL              |
| -------- | ----------------------- | ---------------- |
| consumer | `@measured/next-app`    | `localhost:3000` |
| advisor  | `@measured/advisor-app` | `localhost:3030` |
| admin    | `@measured/admin-app`   | `localhost:3333` |

## Check before starting

The user often already has dev servers running. Check first and reuse them:

```bash
curl -sf -o /dev/null http://localhost:3000 && echo consumer up
curl -sf -o /dev/null http://localhost:3030 && echo advisor up
curl -sf -o /dev/null http://localhost:3333 && echo admin up
```

## Start

```bash
pnpm dev # starts all apps via turbo
```

`pnpm dev` is long-running and never exits. Always run it in the background; never run it as a blocking foreground command.

## Stop

Turbo does not shut down cleanly on a single signal. Killing the parent process can leave orphaned `next dev` children holding the ports, which makes the next start fail with "port in use". After stopping, verify the ports are free and clean up any leftovers:

```bash
lsof -ti:3000,3030,3333 | xargs kill
```
