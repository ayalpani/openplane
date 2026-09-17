# Remove redundant All apps canvas card

Removed footer generation/positioning and empty-list fallback selection. Catalog remains available through Views. Empty Recent/Overview has no ghost Return target. Updated obsolete footer tests to use Views entry and expect no selection when empty.

Ten relevant tests PASS. Signed Release build/signature verification PASS. Synthetic Overview visually inspected, no footer. Installed AX-only Recent selection PASS; next All apps click interrupted by external user app change, stopped further interaction to avoid overriding user. No user screenshots viewed.

P15/P16/P17/P20 full live coverage, core smoke and matched baseline comparisons **NOT RUN: scheduled overnight** for source/build in [identity.json](identity.json). Same safe fixture and measurement method required, first/warm conditions separately. Idle/action/additional CPU and latency **NOT RUN**; calibrated observer/fixture **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No measured gain claimed. Raw source/tests/build evidence retained.
