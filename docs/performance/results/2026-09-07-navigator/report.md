# Movable compact navigator above the Dock

Root cause: Overview/All apps returned a fixed panel rectangle at y=12,
ignoring the stored/dragged origin. All modes now use the existing drag and
persistence path with their actual panel size. Clamp uses NSScreen.visibleFrame
converted into canvas coordinates, plus margins (24 points above a visible Dock,
minimum 96 above canvas bottom for a hidden Dock). Overview reserves the larger
vertical region above or below the moved panel, keeping the nudge exclusion.

PASS: 26 relevant tests (Overview and CanvasSelection), including real mouse
handler drag, header hit-test, position persistence, upper/lower clamp and
non-overlap of the available Overview area. Signed Release build and signature
verification passed. Synthetic card-layer render inspected, no user-window images
viewed. Live native header drag and return verified by persisted coordinates:
see [observations](live-observations.txt). No measured performance gain claimed.

P07/P17 and affected P03/P18/core smoke: **NOT RUN: scheduled overnight**, using
candidate/baseline [identity](identity.json), same warm synthetic fixture and
measurement method. Alternate Dock sides, autohide, monitor changes, All apps
and repeated mode changes remain for that run. Idle CPU, action CPU, additional
CPU and matched baseline latency: **NOT RUN: scheduled overnight**. Calibrated
visual latency/full synthetic live fixture: **BLOCKED**, follow-up
[PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).
No new scheduler. Build/test jobs completed and live lease released afterward.

Evidence: [tests](tests.log), [build](build.log), [source](source.patch),
[synthetic render](synthetic-overview.png). No full performance acceptance claimed.
