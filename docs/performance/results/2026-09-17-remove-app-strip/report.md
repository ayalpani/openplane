# Remove the current-app/history strip — 2026-09-17

## Change and status

P04/P07/P15/P20: remove the requested bottom-left app-name/history strip, its
buttons, hover tracking, icon drawing, content transitions, layout reservation,
delegate callbacks and app-history stacks. Recent's independent window history,
selection, search, settings and minimap remain.

PASS: 79 CanvasMath/CanvasSelection tests and 16 OverviewMode tests; signed
Release build and installation; short live search/view/settings check and visible
strip removal. Updated overlay coverage checks absence of all three removed
button actions in four presentations. Existing minimap layout/drag and preview
activation coverage retained. An initial test edit named All apps as a canvas
mode; corrected to exercise the four presentation indices before the passing run.

Performance acceptance: NOT RUN: scheduled overnight. This is a requested
feature removal, not evidence of a measured performance improvement.

## Identity and evidence

- Baseline source: e97c070; candidate is that commit plus [source.diff](source.diff).
- Source-file/diff hashes and baseline/candidate app hashes: [identity.json](identity.json).
- Baseline installed binary's exact correspondence to e97c070 is not established.
  Preserve source e97c070 for the matched overnight baseline build.
- [Automated tests](tests.log), [overview tests](overview-tests.log),
  [Release build](build.log), [live observations](live-check.txt).
- Baseline app and private preference backup retained outside the repository at
  `/tmp/openplane-strip-removal/`. Candidate installed at `/Applications/OpenPlane.app`;
  strict/deep code-signature verification passed before and after installation.

## Live execution and visual review

Native AppKit app: no Storybook stories exist. Inspected the original installed
app screenshot with the strip and candidate screenshots without it. User windows
changed during development, so these are functional observations, not a matched
performance fixture or pixel comparison. Private window contents are not copied
into the repository. The synthetic overlay screenshot also showed remaining
controls without the strip; it does not establish real preview rendering.

Cmd-F, typed search, Escape, Tab through all four views, Left/Right and Settings
open/close worked. Search selected the matching preview and dimmed other cards.
Return dismissed the overview; destination correctness was not independently
verified. Reopening restored the remaining controls. See raw live notes.

## Measurements and deferred acceptance

| Metric | Baseline | Candidate |
| --- | --- | --- |
| Idle CPU | NOT RUN | NOT RUN |
| Action CPU | NOT RUN | NOT RUN |
| Additional CPU | NOT RUN | NOT RUN |
| Input-to-result/activation latency | NOT RUN | NOT RUN |
| Memory/frame timing | NOT RUN | NOT RUN |

Live check used the existing user session, first previews after app restart then
warm interactions; no cold-cache claim. No timed measurements or paired runs.
Full core smoke, mouse activation, exact activation destination, former strip
area input, narrow layouts, moved minimap and all first/warm variants plus
repeated same-fixture comparisons: NOT RUN: scheduled overnight. Follow-up:
[PERF-025](../../backlog.md), removal case in [runbooks](../../runbooks.md).
No performance gain or complete release performance acceptance claimed.

## Cleanup

Requested candidate remains installed. Settings unchanged; Overview restored,
search cleared, Settings closed. Builds/tests finished and exclusive live-test
lease released. No unattended jobs or new schedules created.
