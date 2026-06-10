---
description: Start work on a Linear ticket - fetch details and create a branch
---

Start work on the Linear ticket: $ARGUMENTS

If no ticket ID was provided, ask for one.

1. Fetch the ticket from Linear (title, description, comments, linked docs).
2. Confirm the working tree is clean; if not, stop and ask how to proceed.
3. Check out the latest main and pull.
4. Create a branch following the repo's branch naming convention (see CLAUDE.md/AGENTS.md). Default format: `feature/{lowercase-ticket-id}-{short-description}`, with the short description derived from the ticket title.
5. Summarize the ticket: requirements, acceptance criteria, and any open questions or ambiguities worth resolving before coding. Do not start implementing.

Linear is read-only for this command: never change ticket status, assignee, labels, or add comments.
