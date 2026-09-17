# Chrome tab count opt-in and right Command

Date: 2026-09-09. Identities: [identity.json](identity.json).

Implemented: default-off Chrome count option, explanatory text before explicit
Automation request, no background prompt, serial off-main count collection every
two seconds while overview visible. Unique title+bounds matching (Chrome session
IDs differ from CG IDs); ambiguous results omitted. No tab URLs or page contents
queried; window titles used transiently only for matching. Shared header renderer.
Default-off right Command tap option shares existing event tap; bare release
opens/closes, chords pass through. Pure input state reset on tap reconfiguration
and recovery. Existing macOS settings preserved.

## Verification

- PASS: 11 focused Overview tests, including right modifier/chord matching,
  Chrome count matching/ambiguity and actual synthetic header rasterization.
- PASS: AppleScript compiled using installed Chrome dictionary, not executed
  against user tabs.
- PASS: signed Release build/install/signature check.
- PASS: synthetic native Settings screenshot: Chrome opt-in and permission
  explanation fit the existing row style without overlap.
- PASS: live AX-only Settings: both new options initially off; explanatory
  Chrome permission copy present; right Command toggle changed to on.
- BLOCKED: automated bare right Command press. CUA returns
  keyPressIncludedNoNonModifierKeys(Super_R). Requested physical user check.
- NOT RUN: live Chrome grant/deny and real tab count refresh. Automation remains
  ungranted by this task; requires controlled test Chrome windows and explicit
  consent. Native header visual review uses synthetic previews only.

## Performance

Baseline binary and full dirty source preserved; same-fixture synthetic before/
after caption correctness covered, no timed performance comparison performed.
Idle CPU, action CPU, additional CPU, reaction/settle latency: NOT RUN: scheduled
overnight, P04/P20/P22 and core smoke. No performance gain claimed.
Controlled browser fixture and calibrated latency observer: BLOCKED, follow-up
[PERF-025](../../backlog.md). Full variants and paired baseline comparisons:
NOT RUN: scheduled overnight. No new automation created.

Cleanup: right Command restored to off via Settings (AX value 0); Chrome
counts remained off, Settings closed, Release left running. No user screenshots
captured or viewed. No timed jobs left running.
