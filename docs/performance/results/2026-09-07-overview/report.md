# Overview layout and per-mode camera following

Overview adds application groups with cascaded separate windows, using a
viewport-aware column search and one fitted camera. Group members retain stable
IDs and their own title/selection/activation. Native tabs inside a single browser
window are not enumerated. Up/Down traverses siblings; other arrows choose a
spatial neighbor in another group; Tab traverses targets. All apps remains available.

Camera follows selection is persisted per mode, default on for Canvas and
Chronological and off for Overview. The setting affects navigation/selection,
not explicit Fit all, opening/reflowing an automatic layout or activating an app.
Canvas geometry/camera storage remains separate from both automatic layouts.
Unchanged inventory does not rerun the grouping/layout search. Groups are fit on
entry, window inventory/size changes and viewport changes. Manual camera movement
remains possible; reopening/Fit all restores the overview.

## Evidence

Identity/source patch and logs accompany this report. The broad targeted run
passed 34 tests. Subsequent focused checks cover the final layout optimization
and visible camera-switch refresh. Synthetic render uses seven fabricated
non-capturable windows and colored images created by the test; no user-window
screenshots viewed. Tests cover all-in-bounds geometry, stacked positions,
sibling and inter-group arrow navigation, stationary camera, mode defaults and
persistence, Canvas frame restoration, viewport resize, unchanged inventory and
empty state. Capture handles absent source windows safely, allowing synthetic
fixtures without accessing the user's screen.

A first installed AX-only check exposed a stale Settings checkbox after mode
switching. Underlying Overview follow-state was off, but the already-created
control retained its previous value. Settings rows now refresh from their menu
items on mode changes and before the panel is shown; a dedicated regression test
checks Canvas on → Overview off → Canvas on.

## Performance and open acceptance

P17/P18 and affected P01–P03/P15/P16: **NOT RUN: scheduled overnight**, against
identity.json. Includes complete window inventories, repeated open/mode switches,
100-window cases, long titles/large sibling groups, direct overlapping-title
clicks, missing/closing windows, mixed monitors and held-key input. Extremely
large groups may have small previews/title spacing after fitting and need the
full synthetic fixture acceptance; do not infer readability from bounds tests.
Use synthetic/local fixtures, never the user's browser screenshots.

Idle CPU, action CPU, additional CPU and matched warmed baseline comparison:
**NOT RUN**. Baseline is the previously installed signed build, recorded in
identity.json. Latency **BLOCKED** by missing calibrated observers:
[PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).
No performance gain or complete live/performance acceptance is claimed. Existing
authorized 03:00 Europe/Berlin round only; no new scheduler.

## Final build and cleanup

[Identity](identity.json), [source](source.patch), [broad tests](tests.log),
[final targeted tests](final-tests.log), [build](build.log),
[synthetic visual](synthetic-overview.png), [live observations](live-observations.txt).
Final targeted tests: two passed, including Settings state refresh. Signature
verification passed. Final installed AX-only check confirmed restart preserves
Overview, follow-selection defaults, correct live checkbox switching, Left/Tab
selection and private previews remaining disabled. No screen-image inspection
of user's windows. Overview remains selected per new feature; other Settings
unchanged. All owned build/test jobs completed, live-test lease released.
