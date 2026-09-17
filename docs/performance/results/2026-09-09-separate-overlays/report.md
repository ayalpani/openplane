# Separate desktop overlays

2026-09-09. Signed Release installed in /Applications/OpenPlane.app.

Persistent search input at lower left; independent current-app/history bar;
standalone Settings button; independently draggable mini-map with overlapping
fit/return and save/forget buttons. Map now visible in all views, with existing
movement policy respected. Map drag avoids the fixed bars and Dock. Saved camera
for automatic/catalog modes has per-view storage; Canvas saved layout preserved.

Validation: 12 Overview tests PASS (tests.log). Covers 480/800/1200-width layout
separation, search/Escape with persistent field, history via native button,
map drag/clamp/persistence, independent camera save and existing selection paths.
Current native synthetic overlay screenshot reviewed (synthetic.png); no exact
same-fixture before screenshot captured. Baseline source patch preserved.
Signed Release build and codesign verification PASS.

Live AX-only: search field present alongside current-app button, Settings,
Fit all windows and Save current position. Click field, type ChatGPT: text value
updates, current-app button remains. Escape empties field without hiding it.
Save changes actions to Return to saved position / Forget saved position; return
clicked without losing overview; forget restores initial state. Search cleared
and temporary saved position removed. User window images never captured/viewed.
Live map drag and precise geometric/camera displacement observation NOT RUN:
requires controlled safe fixture/observer; synthetic map drag test passed.

Performance: idle CPU, action CPU, additional CPU and latency NOT RUN: scheduled
overnight for P04/P07/P15/P20 and full core smoke/five-pair comparisons. Baseline
binary hash and candidate/source identities in identity.json. New Overview and
catalog map rendering must be included, no gain claimed. Missing calibrated
observer and safe live fixture BLOCKED under PERF-025 (../../backlog.md).
