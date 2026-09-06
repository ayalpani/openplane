# Chronological Mode prototype — 2026-09-07

## Status and scope

**Overall performance status: BLOCKED / INCONCLUSIVE.** Functional prototype,
not a full performance certification. Follow-up: [PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).

P15/P16 add the chronological layout, actual-window focus history, Command-Tab
selection, installed-app catalog and mode separation. P01/P02/P03/P04/P09/P10/
P11/P12/P13/P14 variants also require regression coverage.

## Environment and identity

- macOS 26.6.2 (25G83), Mac14,10, 12 logical CPUs; native main-screen session.
- Git base: `09707146f1e93862bfb9e7b734681f28cd1e7020`; existing uncommitted
  changes were preserved. See source manifest and feature diff accompanying this report.
- Baseline: installed `/Applications/OpenPlane.app`, executable SHA-256
  `3c23bdcca77d1292cd67f2b2ee9192c33c730623fad317de5e5a53b57a36ec35`.
  Exact correspondence between that previously installed binary and the initial
  dirty working tree is not established, so it is not a source-matched A/B baseline.
- Candidate: signed Release, installed in `/Applications/OpenPlane.app`.
  Final executable/source identity is recorded in `identity.json`.
- Existing user's main-screen windows and Desktop 2, initial ChatGPT selection;
  Canvas route Down ×3, Up ×3 ended at Ollama in both preliminary runs.
- Preferences backed up outside the repository at
  `/tmp/openplane-chronological/preferences-before.plist`. Personal window
  screenshots remain in the local tool transcript, not repository artifacts.

## Automated and short live checks

- Initial test suite: 97 tests, zero failures. Follow-up relevant selection,
  history and persistence suite: 26 tests, zero failures. Final targeted results
  are retained separately in `final-tests.log`.
- Tested real Settings segment selection Canvas → Chronological, hidden desktop
  controls in Chronological, horizontal centering, vertical ordering and yellow
  selection border using the installed signed Release app.
- Down navigated to Wispr Flow; a settled screenshot showed the selected preview
  centered at the crosshair. Repeated Down reached All apps without launching.
- Return opened the installed-app list. Searching Calculator filtered the display
  to one entry; Return started Calculator (new process verified). The subsequent
  overview retained the chronological zoom of 0.45. These observations establish
  only the exercised paths, not every app/launch/focus scenario.
- Detected an interruption when navigating immediately during Settings closing;
  fixed chronological viewport changes to retain the pending camera destination.
  A targeted automated regression covers resize during camera travel.
- Quick complete Command-Tab was sent through the live UI. The available app-
  targeted tool and concurrent foreground changes do not establish a precise
  key-up-to-target activation trace; do not label the entire shortcut matrix passed.

## Preliminary CPU evidence (not a valid paired comparison)

Raw [baseline](baseline-cpu.json) and [candidate](candidate-canvas-cpu.json) use the
existing `proc_pid_rusage` counter helper and its Mach timebase conversion. CPU
percent is one-core-equivalent. No builds or profilers ran during these samples.

| Measurement | Baseline | Preliminary candidate |
|---|---:|---:|
| Idle sample, seconds | 3.005 | 3.005 |
| Idle CPU, percent | 0.003 | 1.651 |
| Action interval, seconds | 17.408 | 10.406 |
| Action CPU, percent | 0.604 | 17.061 |
| Additional CPU, seconds over idle estimate | 0.105 | 1.604 |

**INCONCLUSIVE:** candidate was newly launched while baseline was already warm;
there were no two controlled warmup rounds. Action windows include orchestration
latency and differ substantially. Baseline lock acquisition was not retained;
candidate live checks used the exclusive live-test lease. These samples are
retained as invalid comparison evidence, not evidence of a gain or a confirmed
regression. A matched-source warmed comparison is required by PERF-022.

First-frame latency, target-ready latency, frame timing, held-modifier variants,
pinch input and repeated retained-memory measurements: **BLOCKED**, calibrated
observers and controlled input/fixture adapters are missing. No missing metric
is interpreted as zero or as a pass.

## Deferred acceptance

**NOT RUN: scheduled overnight** — full P15/P16 variants, affected P01–P04,
P09–P14, core smoke and repeated A/B coverage against the final source/build
identity in `identity.json`. Use the already authorized 03:00 Europe/Berlin round;
no new scheduler or automatic product-change loop was created.

In particular, full live acceptance remains open for same-app multiwindow focus
sequences, closing selected/predecessor windows, held Command with multiple Tabs,
Escape/modifier ordering, safe save-dialog fixtures, inaccessible/missing apps,
startup failures and catalog growth. Automated tests supplement these cases.

## Final installed-build check and cleanup

- Final targeted run: **6 tests, 0 failures**, including delayed window discovery
  after a focus event, removed/reused identities, catalog/back and viewport-change
  camera interruption. Release build succeeded and installed executable matches
  the built executable; signature verification passed (`identity.json`).
- On the final installed build, Settings → Canvas restored all four desktop tabs
  and the saved Canvas camera. A preferences comparison confirms every saved
  desktop's placement geometry, camera and locked camera are unchanged (live
  window session IDs refresh on restart), and the selected
  desktop is unchanged: `canvas-preservation.json`.
- Switched back to Chronological and pressed Down immediately after closing
  Settings. The settled screenshot showed Telegram selected and centered at the
  crosshair, verifying the viewport-interruption fix on the actual app.
- Shift-Down increased chronological zoom from 0.45 to 0.82597, with an enlarged
  selected preview visible. Full held-key/pinch bounds remain overnight work.
- Calculator started by the catalog test was quit; native app inventory confirmed
  it stopped. Original preferences were reimported before the final live checks;
  the new mode/chronological-camera keys remain available for using the prototype.
  No user document was edited or closed. Live-test lease released; owned build,
  test and sampler processes completed. The updated app remains installed.
- Foreground state changed repeatedly during app-targeted automation; these
  observations are intentionally bounded functional evidence, not a clean latency
  campaign or complete activation/focus-sequence acceptance.
