# Final overlay colors — 2026-09-09

User-selected white 75% text and black 10% background are constants. Removed
temporary controls, preference readers/writers, refresh plumbing and reserved
layout/hit areas. Removed obsolete experiment test.

13 OverviewModeTests PASS; Release build/signature verification PASS. Synthetic
fixture reviewed: palette absent, caption layout preserved; transparent fixture
does not verify live backdrop contrast. Installed AX-only search and Tab paths
PASS, original Overview restored. Evidence in live-check.txt.

Baseline search-type identity recorded. Full P07/P20 variants/core smoke and
matched idle/action/additional CPU and latency comparisons: NOT RUN: scheduled
overnight. Calibrated safe observer BLOCKED under
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No full performance verification or performance gains claimed.
