---
description: Review changes with both Codex and Copilot agents and merge their findings
---

Get independent second opinions on the current changes from both external reviewers.

1. Launch the `codex-review` and `copilot-review` agents in parallel on the current branch's changes (diff against main, or the relevant base). Give both the same scope.
2. When both return, merge their findings into a single report:
   - Deduplicate overlapping findings. Mark issues flagged by **both** reviewers — those are the highest-signal items and go first.
   - Categorize everything as high / medium / low severity.
   - Where the reviewers disagree, or where you believe a finding is a false positive, say so and give your own take.
3. Number all items for easy reference (top-level: 1., 2., 3.; sub-items: 2a., 2b.) so the user can respond like "3: please fix" or "2b: stet".

Report only — do not apply any fixes until the user says which items to address.
