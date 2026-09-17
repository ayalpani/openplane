# Search shortcut hint

2026-09-09. ⌘F right-aligned in search field, with reserved space for text and
clear button. Hint also focuses search while preserving an existing query.
Native targeted keyboard/search test PASS; synthetic sidebar-width screenshot
reviewed. No user screenshots viewed. Final one-line query-preservation adjustment
covered by installed live check below.

Baseline binary cd574961c12c8b473b9cddb7e54e8098ce16373ad992d66110d01e3c730c8aa7.
No timed comparison: P07 full live/core smoke and idle/action/additional CPU plus
latency NOT RUN: scheduled overnight. Calibrated observer BLOCKED under PERF-025
(../../backlog.md). No performance gain claimed.

PASS: signed Release build/signature/install. Live AX shows ⌘F hint while idle
and typing. Clicking hint preserves query and focuses field. Escape clears test
query; hint remains. No test settings changed.
