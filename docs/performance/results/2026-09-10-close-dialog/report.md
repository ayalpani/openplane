# Close/quit confirmation handoff — 2026-09-10

Confirmed existing iTerm modal via read-only AX metadata (diagnosis.txt).
Added shared bounded off-main observer after close/quit requests. Modal window
or sheet detection hides overlay and activates target app; never accepts dialog.
Generation/mode/cancellation guards prevent late handoff after navigation.
No-confirm closes preserve overview and existing inventory reconciliation.

WindowBackspaceActionTests and OverviewModeTests PASS; Release build and
signature verification PASS. Live startup PASS; end-to-end handoff NOT RUN:
user focus interruption, stopped further input (live-check.txt). No screenshots
inspected; modal confirm/cancel paths still require safe fixture.

P11/P17 full variants/core smoke and matched idle/action/additional CPU and
latency: NOT RUN: scheduled overnight. Safe destructive-session fixture and
calibrated observer BLOCKED under [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No full functional/performance acceptance claimed. Baseline/source/build identity
in identity.json.
