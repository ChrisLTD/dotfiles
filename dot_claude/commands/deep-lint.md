---
description: Deep-clean codebase review covering bugs, error handling, dead code, and more
---

Read the CLAUDE.md file to get a feel for the codebase — its architecture, conventions, and how the monorepo packages fit together. These files are
your map, but treat them as potentially stale; the code is the source of truth. Validate their assumptions against what you actually find, and flag
any discrepancies.

Today we're doing a deep-clean codebase review. Your priorities, in order:

Functional bugs: Anything that could cause incorrect behavior users would encounter — problems with form submissions, data fetching or display,
navigation flows, state management, query invalidation, optimistic updates, or silent data loss. Trace real data flows end-to-end rather than
trusting function names or comments. Don't believe something works just because the code looks reasonable; verify that the actual logic handles edge
cases, error paths, and boundary conditions across consumer, advisor, and admin apps.

"Good enough" code hiding real problems: Look hard for places where the code mostly works but isn't doing the right thing. This includes: safe
fallbacks or default values that silently mask upstream API errors instead of surfacing them; excessive re-fetching, polling, or redundant queries
that paper over stale cache or invalidation issues rather than solving them; performance costs accepted to avoid getting the data-fetching flow
right; and broad try/catch blocks that swallow exceptions to keep things moving. This is a codebase heavily reliant on React Query and generated API
clients, so some amount of caching and refetching is inherent — but each instance should be critically evaluated. Is that refetchInterval
necessary, or is it compensating for a missing invalidation, a dropped mutation callback, or a state gap? Would a proper query invalidation, an
optimistic update, or a more precise cache key be clearer, more correct, and more performant? The most dangerous code in a codebase like this isn't
code that fails, but code that quietly degrades until the user sees stale data, broken forms, or inconsistent UI.

Missing or inadequate error handling: Places where API failures are swallowed, where invalid or undefined data propagates silently into components,
or where a network error could leave the UI in an inconsistent state — loading spinners that never resolve, forms that silently fail to submit, or
screens that render with partial data.

Cross-package contract issues: Mismatches between what shared packages (ui, app, app-shared, forms, tables, api) export and what consuming apps
expect. Props that are passed but ignored, type assertions that bypass the generated API types, or package boundaries that are violated by reaching
into internal modules.

Missing tests for critical paths: Core functionality that has no test coverage, or where existing tests are so heavily mocked they wouldn't catch a
real regression. Pay particular attention to form validation logic, data transformation layers, and shared utility functions.

Documentation drift: Errors or stale information in the CLAUDE.md file, README files, inline code comments, environment/config examples, and any
other documentation a developer would rely on to set up, run, or understand the project. If the docs describe behavior the code doesn't actually
implement, or omit steps/config that are actually required, flag it. Someone trying to follow the setup instructions on day one will hit these
immediately.

Dead code, duplication, and cruft: Unused components, copy-pasted logic that should be shared via app-shared or ui, commented-out blocks, stale
TODOs, and leftover debug artifacts. Balance this with the monorepo structure: some apparent duplication across apps may be intentional divergence.
Bias towards surfacing duplicated code with caveats over declaring an antipattern.

Architectural concerns: Only if something is glaring enough to cause real problems — this isn't a restructuring pass, but if a design choice is
actively creating bugs, making them easy to introduce, or harder to fix, call it out. Watch for things like business logic leaking into UI
components, shared packages that have grown into grab-bags, or circular dependencies between packages.

For each issue, be specific: identify the file and line(s), explain the problem, describe the conditions under which it manifests, and suggest a fix
where possible. For "good enough" findings, explain both what the code currently does and what the most correct approach would be, even if the
current approach technically works. Present a prioritized summary here, and write your full findings to ./references/hitlist_claude.md.
