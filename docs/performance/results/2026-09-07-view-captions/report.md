# View captions — 2026-09-07

18pt medium overlay captions, large native control, panel height 52 instead of 44; dependent content exclusions follow panel frame. Default chronological display name Recent; internal keys and custom names unchanged.

Source/candidate/baseline: [identity.json](identity.json); complete dirty source [source.patch](source.patch).

Functional: six OverviewModeTests PASS; Release build and signature verification PASS. Synthetic Settings-open rendering visually inspected: readable labels, no overlap. Installed live AX switch Recent → Overview PASS, initial mode restored. No user screenshots viewed.

Performance: P20, affected P03/P17, core smoke and full comparisons **NOT RUN: scheduled overnight**, identified by identity.json. Same P20 fixture and observer required for baseline/candidate; first and warm process conditions separately. Idle CPU, action CPU, additional CPU and latency **NOT RUN**; no gain claimed. Calibrated live observer/fixture coverage **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). Synthetic tests do not replace full live coverage.
