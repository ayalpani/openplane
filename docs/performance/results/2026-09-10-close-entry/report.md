# Backspace removal and Overview entry — 2026-09-10

Code findings: capture results kept updating closing windows; general discovery
and cached AX matches could retain a dead window. Freeze requested previews,
ignore in-flight updates, independently prove exact AX window removal and
publish stack changes immediately. Tombstones prevent stale discovery re-add.
Repeated Backspace while pending ignored. Native dialogs/return retained.

Overview entry now animates card position/transform from source screen rects
to final layout using Core Animation; no persisted layout mutations. Header
fade independent of cards. Cancel on interaction/layout, respect reduce motion.
Canvas/Recent entry unchanged.

CanvasMathTests, OverviewModeTests, WindowBackspaceActionTests PASS. Added entry
start/end and non-mutation/cancellation assertions to grouped synthetic fixture.
Release build and signature PASS. Synthetic final layout generated; animation
geometry tested, physical motion not visually inspected. Live startup observed;
no functional input due active user search (live-check.txt). End-to-end close,
dialog return and native entry NOT RUN. No user windows closed or previews viewed.

P04/P11/P17 full variants/core smoke and same-fixture idle/action/additional CPU,
pending-close CPU and latency comparisons NOT RUN: scheduled overnight.
Safe live scene/calibrated motion observer and physical modifier adapter
BLOCKED under [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No full performance acceptance or measured speedup claimed.
