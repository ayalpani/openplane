# Animated return to original app — 2026-09-10

Capture actual foreground window/app when entering overview (actual focus
observer fallback). Right Command and Q share returnToOverviewOrigin, invoking
existing Return focus animation on the saved target, not cursor selection.
Exact window preferred; same-app fallback only; missing origin shows status.
Search cleared on intentional return; Q typing retained in search/Settings,
repeat suppressed. Opening cancellation retains existing rapid-toggle guard.

39 OverviewModeTests/CanvasSelectionTests PASS. New Q dispatch test verifies
no selection launch, no repeat and search typing. Initial fixture depended on
old Canvas default; now explicitly sets/restores Canvas mode. It also exposed
existing single-search-arrow gap, corrected with conditional positioning.
Release build and strict signature PASS. Installed live startup/reopen observed;
Q source-to-destination test interrupted by external focus changes, NOT VERIFIED.
No live screenshots inspected. Physical right modifier cannot be injected by
available UI adapter.

P04/P17 full input variants/core smoke and matched idle/action/additional CPU
and latency NOT RUN: scheduled overnight. Physical modifier adapter, controlled
foreground fixture and calibrated observer BLOCKED under
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No full performance or live functional acceptance claimed.
