# Search action swap — 2026-09-09

Search shortcut is replaced by X on focus, including an empty field clicked
with the mouse. Both controls share the same center; text width remains fixed.
14 OverviewModeTests PASS; Release build and signature verification PASS.
Installed AX-only focus/click/keyboard checks PASS (live-check.txt). No live
user screenshots viewed. Native layout change is small enough that screenshot
comparison was skipped; geometry verified in source, AX visibility live.

Baseline: temporary-colors binary; exact source/build in identity.json.
P07/P20 full variants/core smoke and matched idle/action/additional CPU and
latency: NOT RUN: scheduled overnight. Safe calibrated observer BLOCKED under
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No full performance verification or gain claimed.
