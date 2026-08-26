---
name: pr-recordings
description: Record a short screen capture of a feature working, for PR descriptions or review, by driving the existing Playwright e2e harness against the locally running app and transcoding the result to MP4 with HandBrake. Use when asked to record a feature, capture a video or screen recording, or attach a demo clip to a PR. Measured monorepo (measured-fi/measured-app) only.
---

# Recording a feature with Playwright

The video counterpart to `pr-screenshots`. Same harness, same auth, same
locally-running app — Playwright records the browser context to WebM, then
HandBrake transcodes it to an MP4 small enough for a GitHub attachment.

Reach for a recording only when motion is the point: a multi-step flow, a
transition, a drag interaction. For anything a reviewer could read in one frame,
use `pr-screenshots` instead — a still is faster to review and easier to comment on.

## Prerequisites

- Everything `pr-screenshots` requires: the app running locally (admin `:3333`,
  advisor `:3030`, consumer `:3000`) and `.env.local` holding the login creds.
- `HandBrakeCLI` on `PATH` (`brew install handbrake` — the `handbrake-app` cask is
  the GUI and ships no CLI binary).

## Steps

1. **Write a temporary spec** under `e2e/tests/{app}/`, same placement rule as
   screenshots so it inherits that project's auth. Video options go in
   `test.use` — the config sets none globally, so nothing else records.

   ```ts
   import { expect, test } from '~/helpers/authed-test';

   test.describe('record', () => {
     test.use({
       viewport: { width: 1440, height: 900 },
       video: { mode: 'on', size: { width: 1440, height: 900 } },
     });

     test('application review flow', async ({ page }) => {
       await page.goto('/applications');
       await expect(page.getByTestId('applications-table')).toBeVisible();

       const rows = page.getByTestId('application-row-link');
       await expect(rows.first()).toBeVisible();

       // Navigate via href — client-side row clicks are flaky under Playwright.
       const href = await rows.nth(0).getAttribute('href');
       await page.goto(href!);
       await expect(page.getByTestId('app-facts-card').first()).toBeVisible();
     });
   });
   ```

2. **Run local, single worker.** `SLOW_MO` is wired into the config's
   `launchOptions` and is what makes a recording watchable — without it the flow
   completes faster than a reviewer can follow.

   ```bash
   cd e2e && TEST_ENV=local SLOW_MO=250 PLAYWRIGHT_FULLY_PARALLEL=false WORKERS=1 \
     npx playwright test tests/admin/<spec>.spec.ts --project=admin --reporter=list
   ```

3. **Find the WebM.** Playwright finalizes the video when the context closes, so
   it only exists once the run finishes. It lands under the default output dir,
   in a folder named after the test:

   ```bash
   find e2e/test-results -name video.webm
   # e2e/test-results/admin-<spec>-record-application-review-flow-admin/video.webm
   ```

4. **Transcode to MP4** into `.scratch/recordings/`, naming the output after that
   folder so the clip stays tied to its test:

   ```bash
   mkdir -p .scratch/recordings
   find e2e/test-results -name video.webm | while read -r v; do
     name=$(basename "$(dirname "$v")")
     HandBrakeCLI -i "$v" -o ".scratch/recordings/${name}.mp4" \
       -e x264 --encoder-preset veryfast -q 22 \
       --vfr -a none --optimize 2>/dev/null
   done
   ls -lh .scratch/recordings/
   ```

   - `--vfr` preserves the source timing; Playwright's WebM has a ragged frame rate.
   - `-a none` drops the audio track Playwright never recorded.
   - `--optimize` moves the moov atom to the front so GitHub streams the clip
     instead of waiting on a full download.
   - `-q` is an inverted quality scale: lower is better and bigger. 22 keeps UI
     text crisp; raise it toward 28 only if you need to fit the cap.

5. **Check the size against GitHub's cap** — 10MB for a repo on a free plan,
   100MB on a paid one. If it's over, re-encode at a higher `-q` or add
   `--width 1280` before trimming the flow itself.

6. **Clean up** — the capture spec is never committed, and `test-results` holds
   the raw WebM:

   ```bash
   rm -f e2e/tests/admin/<spec>.spec.ts && rm -rf e2e/test-results e2e/playwright-report
   ```

7. **Deliver** the MP4 (SendUserFile) so it's on hand for the PR.

## Alternative: recording with playwright-cli

When the clip needs to show *where* each click landed, `playwright-cli` is the
better recorder. `video-show-actions` draws a synthetic cursor, a marker at the
click point, a highlight on the target element, and a label naming the action,
which is the one thing the harness path cannot do. It also writes the WebM
straight to the filename you give it, so step 3's `find` and step 6's
`test-results` cleanup both disappear.

```bash
playwright-cli -s=rec open
playwright-cli -s=rec state-load "$PWD/e2e/.auth/admin.local.json"
playwright-cli -s=rec goto http://localhost:3333/applications
playwright-cli -s=rec video-start flow.webm
playwright-cli -s=rec video-show-actions --duration=1500
# ...drive the flow, one command per step...
playwright-cli -s=rec video-chapter "Reviewing the application"
playwright-cli -s=rec video-stop
playwright-cli -s=rec close
```

Transcode the result with the same HandBrake command in step 4. Auth comes from
the harness either way, so refresh it first with
`--project={app}-setup` when the saved state is older than 4 minutes.

Stay with the spec-driven path above when the recording is of a flow you will
want to re-record later; a spec reruns, a CLI sequence does not.

## Gotchas

- **No mouse cursor.** Chromium's screencast doesn't composite the pointer, so
  clicks are invisible and the UI just reacts. Either record with `playwright-cli`
  instead (see below), narrate the interaction in the PR description, or fall back
  to screenshots with the target visibly focused.
- **Keep it under ~20 seconds.** Reviewers scrub, and a long clip buries the one
  moment you wanted them to see. Record one flow per test; several short clips
  beat one long one.
- **Match `video.size` to the viewport.** A mismatch makes Playwright rescale the
  frames and UI text turns mushy.
- **`mode: 'on'` keeps the video on success.** `retain-on-failure` deletes it when
  the test passes, which is exactly the case you're recording for.
- Don't `await video.saveAs()` inside the test — it blocks until the page closes
  and will hang the test until timeout. Rename after the run instead (step 4).
- If `npx playwright` reports `playwright: command not found`, the shell cwd reset
  to the repo root — `cd e2e` first.

## Attaching to a GitHub PR

Same constraint as screenshots: GitHub only hosts attachments uploaded through its
own editor, with no token/API path for `user-attachments`. Either drag the MP4 into
the PR description's "Screenshots / Videos" section by hand, or, if the Claude
Chrome extension is connected, upload it via browser automation (`file_upload` onto
the comment form's file input). GitHub renders an inline player from the resulting
URL — no markdown image syntax needed.
