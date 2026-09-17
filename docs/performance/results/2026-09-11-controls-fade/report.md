# Early navigation controls fade — 2026-09-11

P04/P17: navigation overlays use an ease curve completed in first third of camera flight. Shared focus path covers right Command, Q, Return and click. Preview/backdrop and window activation timings unchanged. Existing focus cancellation resets progress to zero, restoring control opacity.

PASS: 42 automated tests, Release build, code signature and installation. Live Return handoff and reopening checked through AX (live-check.txt). Exact visual fade/restore not established by AX. No screenshot inspected. Small animation-only change with no layout addition; no Storybook exists for native AppKit, no pixel comparison performed.

Candidate/baseline identity and full dirty source.patch preserved. NOT RUN: scheduled overnight — full P04/P17 variants/core smoke, paired baseline comparison; idle/action/additional CPU and latency each unmeasured. Same safe fixture with fresh/warm previews required. Physical right Command and calibrated visual observer BLOCKED under PERF-025, ../../backlog.md. No measured performance gains or full visual acceptance claimed.

User settings untouched. OpenPlane reopened, test lease released.
