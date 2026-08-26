---
name: pr-screenshots
description: Generate screenshots of a feature working, for PR descriptions or review, by driving the existing Playwright e2e harness against the locally running app. Use when asked to screenshot a feature, capture the UI, or attach screenshots to a PR. Measured monorepo (measured-fi/measured-app) only.
---

# Generating screenshots with Playwright

Drive the existing e2e harness against the **locally running** app (not a deployed
env) so screenshots reflect the working-tree code. Reuses the harness's Auth0 login.

## Prerequisites

- The target app must be running locally: admin `:3333`, advisor `:3030`, consumer `:3000`.
  Check with `curl -s -o /dev/null -w "%{http_code}" http://localhost:3333`.
  If it's not up, start it (see the `dev-servers` / `run` skills) before capturing.
- `.env.local` must hold the app's login creds (`ADMIN_USERNAME` / `ADMIN_PASSWORD`
  / `ADMIN_TOTP_SECRET`, etc.). The `{app}-setup` project re-logs in automatically
  when the saved `.auth/{app}.local.json` session is stale (>4 min old).

## Steps

1. **Write a temporary spec** under `e2e/tests/{app}/` (e.g. `tests/admin/`) so it
   runs under that Playwright project and inherits its auth. Save images to
   `.scratch/screenshots/`. Template:

   ```ts
   import { expect, test } from '~/helpers/authed-test';

   const SHOT_DIR = '/absolute/path/to/repo/.scratch/screenshots';

   test.describe('capture', () => {
     test.use({ viewport: { width: 1440, height: 900 } });

     test('feature', async ({ page }) => {
       await page.goto('/applications');
       await expect(page.getByTestId('applications-table')).toBeVisible();

       const rows = page.getByTestId('application-row-link');
       await expect(rows.first()).toBeVisible();
       await page.screenshot({ path: `${SHOT_DIR}/01-list.png` });

       // Navigate via href — client-side row clicks are flaky under Playwright.
       const href = await rows.nth(0).getAttribute('href');
       await page.goto(href!);
       const card = page.getByTestId('app-facts-card').first();
       await expect(card).toBeVisible();
       await page.screenshot({ path: `${SHOT_DIR}/02-detail.png` });
     });
   });
   ```

2. **Run local, single worker** (from the `e2e` dir):

   ```bash
   cd e2e && TEST_ENV=local PLAYWRIGHT_FULLY_PARALLEL=false WORKERS=1 \
     npx playwright test tests/admin/<spec>.spec.ts --project=admin --reporter=list
   ```

   Swap `--project` and the base URL per app: `admin` / `advisor` / `consumer`.
   `TEST_ENV=local` reads `.env.local`, which points the base URL at localhost.

3. **Read the PNGs** to confirm the feature rendered as intended.

4. **Clean up** — the capture spec is never committed:

   ```bash
   rm -f e2e/tests/admin/<spec>.spec.ts && rm -rf e2e/test-results e2e/playwright-report
   ```

5. **Deliver** the images (SendUserFile) so they're on hand for the PR.

## One-off captures with playwright-cli

For a single screenshot that nobody needs to reproduce, `playwright-cli` skips the
temporary spec and the cleanup entirely:

```bash
playwright-cli -s=shot open
playwright-cli -s=shot state-load "$PWD/e2e/.auth/admin.local.json"
playwright-cli -s=shot goto http://localhost:3333/applications
playwright-cli -s=shot screenshot --filename=.scratch/screenshots/01-list.png
playwright-cli -s=shot close
```

Auth still comes from the harness, so refresh it first with `--project={app}-setup`
when the saved state is older than 4 minutes; a stale file fails silently and lands
you on the Auth0 login page. Its default action timeout is 5s, which these apps can
exceed on a cold route, so `goto` and retry rather than assuming the element is missing.

Use the spec-driven path above for anything you will want to re-capture after a
change, and for a set of shots that has to stay consistent across runs.

## Gotchas

- Prefer a fixed viewport over `fullPage` for long tables — a full-page shot of a
  100-row list is thousands of px tall and unreadable.
- Navigate to a row's `href` instead of clicking it; client-side row-link clicks
  frequently fail to navigate under Playwright.
- If a `pnpm`/`npx` run reports `playwright: command not found`, the shell cwd is
  the repo root — `cd e2e` first (the persisted Bash cwd may have reset).

## Attaching to a GitHub PR

GitHub only hosts images uploaded through its own editor — there is no token/API
path for `user-attachments`. So either drag the delivered PNGs into the PR
description's "Screenshots / Videos" section by hand, or, if the Claude Chrome
extension is connected, upload them into the description via browser automation
(`file_upload` onto the comment form's file input).
