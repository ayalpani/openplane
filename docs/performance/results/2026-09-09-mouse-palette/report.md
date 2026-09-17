# Mouse-only palette and shared typography — 2026-09-09

Removed temporary palette keyboard routing, focus traversal and shortcut. Native
buttons/sliders refuse first responder and key-view membership; mouse actions
remain. Search/path typography shares ViewModeControl.labelFont (20pt semibold).

14 OverviewModeTests PASS, including non-focusable controls, mouse action updates
and Tab/Shift-Tab view changes. Release build and signature verification PASS.
Synthetic native fixture reviewed: larger captions fit both bars and align with
top navigation type size. Installed short AX-only click then Tab/Shift-Tab PASS;
user palette settings and Overview restored. See live-check.txt.

Baseline search-swap build in identity.json. Full P07/P20 variants/core smoke,
slider drag matrix, and matched idle/action/additional CPU and latency comparisons:
NOT RUN: scheduled overnight. Safe calibrated observer BLOCKED under
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No performance gain or complete performance verification claimed.
