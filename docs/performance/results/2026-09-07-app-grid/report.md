# Full-width application grid

Catalog uses width-adaptive columns in alphabetical row-major order. 56-point
icons and app names occupy 128-point tiles. Arrow navigation uses spatial
neighbors; selection scrolls into view rather than centering every tile.
A compact bottom control panel replaces the catalog minimap. Back restores the
window canvas. Search rebuilds the filtered grid; viewport layout recalculates
columns. Existing launch/error paths remain in use.

[Identity](identity.json), [patch](source.patch), [tests](tests.log),
[render test](render.log), [build](build.log). Relevant tests passed, including
row-major placement/bounds and actual card-layer geometry across the viewport.
[Visual evidence](synthetic-grid.png) uses only synthetic Example apps and a
system icon. No user's window screenshots viewed. Short AX-only signed Release
check: overview → All apps → catalog opened with Activity Monitor selected and
Back button. Final build differs only by extracting the tested catalog-update
method; rebuilt, reinstalled, signature verified.

P16 catalog width/resize/scroll/arrow/search/click/Return/Back and P03 zoom:
**NOT RUN: scheduled overnight**, full variants against identity.json. Idle CPU,
action CPU, additional CPU: NOT RUN. Matched warmed baseline comparison: NOT RUN;
previous layout was one vertical column. Latency **BLOCKED** by missing calibrated
observer, [PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).
No performance gain claimed. Synthetic visual checks supplement, not replace,
full installed live acceptance. Existing authorized overnight round only.
Build/test jobs completed and live lease released. No Settings toggles changed.
