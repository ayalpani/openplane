# Browser privacy containment — 2026-09-07

Root cause: detection treated absence of private-mode words in a page/window title
as safe. Such a title cannot establish non-private mode. With private previews
disabled, all recognized browsers now fail closed, including ordinary windows.
This is deliberate containment, **not completed private/non-private classification**.
Other applications retain previews. Before/after-await capture guards and the
final application guard respect preference changes during capture. Browser
images are never persisted or loaded from disk, even if explicitly enabled;
legacy browser cache files are removed by filename without decoding them.

69 cached preview files removed after stopping OpenPlane; second cleanup found
zero. No screenshots were viewed. [Observed metadata](observations.json).
Signed Release installed in `/Applications/OpenPlane.app`, signature verified;
AX-only launch check succeeded. [Identity](identity.json), [source](source.patch),
[build](build.log), [tests](tests.log). Three targeted tests passed, using synthetic
blue pixels only: title-independent suppression, unrelated-app preservation,
cache roundtrip/browser rejection/legacy deletion, plus legacy title detection.

Visual review **NOT RUN: user explicitly prohibited viewing screenshots**. Do not
capture this user's browser UI as nightly evidence either. Use a separate,
non-sensitive local fixture. Full live enforcement/focus-switch/toggle-in-flight
coverage and known-normal browser classification remain open: [PERF-023](../../backlog.md#perf-023--browser-privatmodus-verlässlich-unterscheiden).

P12 privacy-setting variants and P02 capture/cache variants, source/build in
identity.json: **NOT RUN: scheduled overnight** in the existing authorized round.
Idle CPU, action CPU, additional CPU: NOT RUN. Latency: BLOCKED (calibrated
observer missing, PERF-022). Baseline hash recorded but no matched fixture A/B
run. Never claim performance improvements from suppressing browser previews.

Owned test/build jobs finished, live-test lease released. Protection explicitly
left OFF for private previews per user request; new Release remains installed.
