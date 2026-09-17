# Rounded view pill and browser filtering removal

Explicit user request removes browser filtering and Settings toggle, including private windows. Legacy preference ignored centrally by all capture/refresh gates. Browser disk caching remains disabled. PERF-023 containment superseded, not claimed completed.

View control uses text-sized segments, 20pt semibold font, 14pt horizontal inner padding, 4pt outer inset, fully rounded panel and 240ms ease-in/out blue highlight. Reduce Motion skips animation. Standard buttons retain focus/action accessibility, exposed once per radio button.

Validation: seven focused tests PASS plus rapid reversal/settled selection test PASS (eight total). Synthetic rendering visually inspected. Signed Release builds/signature verification PASS. Live initial AX switch Overview → Canvas passed; final AX-only correction verified four distinct controls. Final repeat interrupted by external user interaction and no visible app window; no further UI actions. Source/build/baseline in identity.json, raw logs retained.

P02/P12 browser capture live verification **NOT RUN**: no user browser content inspected, safe paired browser fixture/observer needed, [PERF-022](../../backlog.md#perf-022). Unit test confirms removed gate ignores false legacy preference even for private windows; not evidence of a live captured Chrome frame.

P20 full input/animation coverage, P02/P12, core smoke and same-fixture baseline comparisons **NOT RUN: scheduled overnight**, source/build identity in identity.json. Idle CPU, action CPU, additional CPU, latency **NOT RUN**; calibrated observer/fixture **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No performance gain claimed. Same safe fixture and observer required for baseline/candidate, first and warm conditions separately.
