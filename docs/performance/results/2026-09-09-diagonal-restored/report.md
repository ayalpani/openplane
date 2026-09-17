# Restore right/down stacks

User-requested rollback of perspective sizing and stack movement to saved stack-exit source. Retains active-to-front ordering, remembered fronts, MRU close fallback, row boundary exit, Overview-first tabs and later caption keep-visible fix. Focus cancellation recovery retained. Removes perspective-specific rendering/focus geometry and animation code/tests.

Nine Overview tests PASS. Native synthetic scene visually verified: right/down offset cards, active card front with yellow outline, shared captions. Signed Release build/signature PASS; installed AX Down changes ChatGPT to Google Chrome, Up remains within Chrome (AX only exposes app label). Overview visible for user review. No user screenshot viewed.

P04/P20 full live variants/core smoke/matched baseline **NOT RUN: scheduled overnight**, source/build in identity.json. Same safe fixture, first/warm cache. Idle/action/additional CPU and presented latency NOT RUN. Controlled fixture/calibrated observer **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No performance gain claimed.
