# Overview entry source depth — 2026-09-10

Snapshot macOS visible window order immediately before reveal; keep source
zPosition through entry animation. Missing source IDs render behind visible
ones. Final model depth untouched; completion/interruption returns normal
Overview ordering.

OverviewModeTests PASS; final grouped-window test PASS after fallback refinement.
Assertions check reversed source ranks, constant animation depth, unchanged model
frames and restored depth on interruption. Release build/signature PASS.
Short installed AX startup/reopen/search/X check PASS; physical motion/occlusion
not visually observed to preserve screenshot privacy. No geometry change; native
regression covers layer ordering, no new screenshot comparison.

P04/P17 full variants/core smoke and matched idle/action/additional CPU and
latency NOT RUN: scheduled overnight. Physical modifier input and calibrated
display observer BLOCKED under [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No complete performance verification or measured gain claimed.
