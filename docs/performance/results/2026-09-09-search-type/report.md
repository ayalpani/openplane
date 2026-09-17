# Search typography and current-app icon — 2026-09-09

Search apps… and shortcut share regular 20pt font; current-app icon 32pt,
8pt vertical margins and title gap. Explicit native cell drawing preserves
single-line title truncation and native button action/accessibility.

14 OverviewModeTests PASS, Release build and signature verification PASS.
Synthetic native fixture visually reviewed (synthetic.png): regular search and
shortcut fit, icon/title aligned, no clipping. Installed short AX-only hint
activation and Escape restoration PASS (live-check.txt). Live pixel inspection
not performed to preserve user screenshot privacy.

Baseline mouse-palette identity recorded. P07/P20 full variants/core smoke and
matched idle/action/additional CPU and latency: NOT RUN: scheduled overnight.
Safe calibrated observer BLOCKED under
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No performance gain or full performance verification claimed.
