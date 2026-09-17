# Remove catalog Back button

Removed redundant button, target/action and layout/visibility code. Views overlay and Escape return remain.

Four ChronologicalModeTests PASS; signed Release build/verification PASS. Synthetic catalog render inspected. Installed AX-only All apps → Overview switch PASS; initial mode restored. Source, build and baseline identities in [identity.json](identity.json).

P16/P20 full live coverage, core smoke and same-fixture baseline comparisons: **NOT RUN: scheduled overnight** for this source/build. First/warm catalog opens, click/keyboard switch and search/Escape paths remain required. Idle/action/additional CPU and latency: **NOT RUN**, no performance gain claimed. Calibrated observer/fixture coverage **BLOCKED**: [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). Raw tests/build/live evidence retained here.
