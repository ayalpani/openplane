# Overview stack exits and first tab

Removed modulo wrap trapping Up/Down at stack boundaries, including singleton apps. At a boundary spatial navigation proceeds between whole-app bounds, avoiding staggered-card offsets masquerading as another row. Remembered front remains selected on entry. Presentation order now Overview/Canvas/Recent/All apps in top nudge and Settings, mapped from persistent string identifiers rather than enum index; stored modes unchanged.

Nine Overview tests PASS: explicit multi-row exit, singleton exit, remembered return, layered content and saved Canvas geometry; forward/reverse Tab and Settings mappings checked. Signed Release build/signature PASS. Installed live Down changed app selection Claude → Google Chrome, AX top-tab order confirmed. Up live check interrupted by user input; no further input sent. No personal previews inspected.

P04/P20 full input/core smoke and matched baseline **NOT RUN: scheduled overnight** with source/build in identity.json. Same safe fixture and first/warm cache required. Idle/action/additional CPU and presented latency NOT RUN. Calibrated observer and controlled live multi-stack fixture **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No performance gain claimed.
