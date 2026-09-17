# Overview: reserve the desktop title nudge

The previous fixed 48-point top margin was smaller than the rendered nudge.
Packing and camera fitting now share the available rectangle, excluding the
full nudge depth (including display safe-area) plus 24 points. The lower control
panel remains excluded. Available-frame changes invalidate layout; preview-size
Fit all no longer overrides the Overview fit with the generic full-canvas fit.
Canvas/Chronological behavior is unchanged.

## Checks

PASS: two focused Overview tests, including decorated preview containment,
resize, preview-size refit, navigation and Canvas restoration. Signed Release
build and signature verification passed. Synthetic card-layer render inspected;
no user screenshots viewed. AX-only installed live check: Fit all button then
Right changed the selected target from WhatsApp to Telegram, app remained open.
Pixel-level live nudge exclusion is not established by AX; synthetic geometry
checks cover that invariant. No performance improvement is claimed.

## Deferred acceptance

P17 nudge variants and affected P03/P18/core smoke: **NOT RUN: scheduled overnight**
for the candidate and baseline identified in [identity.json](identity.json).
Use the same synthetic fixture, warm/cold process boundaries, varied safe-area
heights, opening/resize/Fit all/preview-size changes. Idle CPU, action CPU,
additional CPU and paired baseline timings: **NOT RUN: scheduled overnight**.
Calibrated visual latency and complete synthetic live fixture: **BLOCKED**;
follow-up [PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).
No real user-window screenshots may be used. No new scheduler created.

Evidence: [tests](tests.log), [build](build.log), [source](source.patch),
[synthetic render](synthetic-overview.png). Owned build/test jobs completed;
live lease released after the check. User settings preserved.
