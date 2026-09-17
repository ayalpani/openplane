# Right Command toggle parity — 2026-09-11

P04/P17. Fix: recognized presses are retained modulo 2 while discovery/focus/return/dismissal is busy; lifecycle completion drains pending parity through existing open/origin-focus functions. Cancellation also schedules a drain. No duplicate activation/animation implementation.

Baseline: installed return-origin binary; candidate identities in identity.json and full dirty source.patch.

Automated: PASS, 40 tests, zero failures. Covers odd/even pending presses, preservation during transitions and consume-once. These tests ran before the final two cancellation-drain hooks; final Release compiles those hooks successfully. Signed Release build/install/signature PASS. Live launch AX check PASS; origin-return Q check INCONCLUSIVE without controlled origin. Physical rapid right-Command sequence BLOCKED: UI tool lacks bare-modifier synthesis. See live-check.txt and PERF-025 in ../../backlog.md.

Idle CPU, action CPU, additional CPU, latency and paired baseline comparison: NOT RUN: scheduled overnight, P04/P17 plus core smoke, with candidate identity.json. First-process and warm-process safe fixture comparisons required. Calibrated display observer and physical modifier input remain BLOCKED under PERF-025. No performance improvement or complete live acceptance claimed.

No screenshots inspected; no settings changed. Live lease released after checks.
