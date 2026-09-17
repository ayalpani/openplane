# Centered search and handoff flash — 2026-09-17

## Findings and change

P04/P07/P17/P20. Search now uses the canvas horizontal center. Minimap collision
avoidance continues to reserve its actual frame, including narrow layouts.

A new regression test on source 805f1a0 fails three assertions: Overview headers
remain opaque during handoff, completed handoff restores controls immediately,
and a later scene refresh still exposes the header. This establishes rendering
state defects, not the identity of the reported transient Ollama icon.

Completed focus now retains the hidden rendering state until overview preparation;
interrupted focus still restores controls and notifies its delegate. Overview
headers fade with the other background cards. The overlay window no longer
resets its alpha immediately after being ordered out; opening paths restore it.
Recent history, selection, animation durations and activation behavior remain.

## Verification

- PASS: baseline regression reproduced ([baseline-test.log](baseline-test.log)).
- PASS: 43 candidate OverviewMode/CanvasSelection tests, including the same
  regression, interruption behavior and search centering at 480/800/1200 widths
  ([tests.log](tests.log)).
- PASS: signed Release build, strict/deep signature verification and installation
  in `/Applications/OpenPlane.app` ([build.log](build.log)).
- Short live check: centered search in Canvas/Overview, filter result, Return and
  Q dismissal, reopen with controls visible. [Live notes](live-check.txt) retain
  tool limitations and unsuccessful input attempts.
- No Storybook exists for native AppKit. Baseline and candidate screenshots were
  inspected, with private window contents retained only in task observations.

Physical right Command: BLOCKED by UI tool rejection of modifier-only input.
Exact subsecond compositor flash and destination correctness: not independently
verified. Do not claim that the user's precise symptom is conclusively resolved.
Follow-up remains [PERF-025](../../backlog.md).

## Identity and measurement limits

Baseline source 805f1a0 and candidate [source.diff](source.diff), source/binary
hashes and installed Release identity: [identity.json](identity.json). Baseline
app and original preferences retained privately in `/tmp/openplane-centered-search/`.
Baseline binary matches the preceding removal report's candidate hash.

| Metric | Baseline | Candidate |
| --- | --- | --- |
| Idle CPU | NOT RUN | NOT RUN |
| Action CPU | NOT RUN | NOT RUN |
| Additional CPU | NOT RUN | NOT RUN |
| Input/activation latency | NOT RUN | NOT RUN |
| Frame times and memory | NOT RUN | NOT RUN |

The live check used the existing user session; first previews after app restart
and subsequent warm interactions, without deliberate cache clearing. It is not
a controlled paired timing fixture. Full core smoke, all close/reopen/input
variants, centered-search Settings/Dock layouts, and repeated baseline/candidate
CPU/latency comparisons: NOT RUN: scheduled overnight, under the new runbook case.
No performance gains or complete release performance acceptance claimed.

## Cleanup

Candidate remains installed. Canvas restored with empty search; no user settings
changed through Settings. Build/test jobs finished; exclusive live-test lease
released. No new schedules or unattended loops created.
