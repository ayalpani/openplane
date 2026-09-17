# Transition speed — 2026-09-11

P04/P17: shared persisted 0.5×–4× speed, default 2×. Entry 0.45/speed, Canvas return 0.35/speed, shared focus 0.6/speed seconds. Internal handoff fractions preserved.

PASS: 41 relevant tests; signed Release build/install; keyboard live Settings slider check (see live-check.txt). Defaults, bounds and nonfinite values covered. Small native AppKit slider addition; no Storybook exists and no pixel comparison performed. Live checks used AX only, respecting screenshot privacy.

Baseline/candidate source and binary in identity.json; full dirty source.patch preserved. NOT RUN: scheduled overnight — full P04/P17 variants/core smoke, paired idle CPU/action CPU/additional CPU and latency on same safe fresh-process/warm fixture. Physical right Command and calibrated visual handoff observer BLOCKED under PERF-025 in ../../backlog.md. No measured performance gain claimed.

Slider restored to requested 2× after live check; Settings closed, test lease released.
