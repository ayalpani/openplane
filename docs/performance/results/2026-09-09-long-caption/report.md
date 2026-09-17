# Long title disappears despite visible layer

Live diagnostic captured only title length and layer geometry/opacity (no actual title/image): first Chrome item 71 characters, valid frame, visible flags and opacity 1. Reproduced with long synthetic title: metadata visibility passed but actual caption rendered blank. Shared attributed header now has explicit single-line tail-truncation paragraph style; CATextLayer font size matches text and wrapping disabled. Before/after native raster shows blank → visible truncated caption. Previous zoom/duplicate-instance explanations did not resolve this failure.

Nine Overview tests PASS including first/middle/last strings and new actual caption pixel check. Signed Release build/signature and installed AX launch PASS. User previews never inspected; full installed visual confirmation NOT RUN. Temporary diagnostic code removed and headerDiagnostics preference deleted. Source retained includes test coverage.

P04/P20 full live variants/core smoke/matched CPU/latency baseline NOT RUN: scheduled overnight; identity.json records source/build. Idle/action/additional CPU and latency NOT RUN. Controlled safe fixture/calibrated observer BLOCKED under [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). Native visual before/after is functional evidence, not performance measurement.
