# Temporary overlay color controls — 2026-09-09

Disposable native control bar for jointly tuning search and position overlays.
Black/white color switches, opacity sliders and percentages; values retained
locally until the chosen final colors replace this temporary code.

14 targeted OverviewModeTests PASS (tests.log), Release build PASS (build.log),
signature verification PASS. Synthetic native fixture visually reviewed: controls
fit with aligned rows and no clipping; no user preview images inspected.
Short installed AX-only keyboard and mouse check PASS (live-check.txt); original
values restored. Test covers immediate search color/opacity updates and keyboard
background changes. Live rendered color measurement was not performed.

Baseline is prior light-bars build, hash in identity.json. Full P07/P20 variants,
core smoke and matched idle/action/additional CPU and latency comparisons:
NOT RUN: scheduled overnight. Calibrated safe fixture/observer BLOCKED under
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No performance improvement or full performance verification claimed.
