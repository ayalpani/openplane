# Chronological spacing and fixed All apps label

Canvas and chronological placement share CanvasMath.itemGap (240 world units,
previous chronological gap 100). Footer/catalog gaps use the same constant.
All apps uses fixed 18-point type and 21.6-point icon, independent of zoom.
Minimum displayed card size 160×48 keeps the contents inside the hit target;
zoom-driven resizing preserves its center.

[Build/source identity](identity.json), [patch](source.patch), [tests](tests.log),
[render test](render.log), [Release build](build.log). Relevant RecentWindowOrder
and ChronologicalMode tests passed. Actual card-layer render with empty synthetic
Canvas, no captured windows: [small zoom](synthetic-small.png),
[large zoom](synthetic-large.png). Same text/icon size visibly confirmed. Initial
root-view export was blank and rejected; card-layer export used instead.

Signed Release installed and signature verified. Short AX-only live check under
exclusive lease: All apps found via search, Return opened alphabetical catalog
(Activity Monitor and Back button), Escape returned. No user window screenshot
was requested or viewed. Synthetic card render supplements but does not replace
full live visual acceptance. No app settings changed during the live check.

P15/P16 spacing at mixed sizes/zoom, selected neighbors, footer hit area after
zoom, P03 zoom variants: **NOT RUN: scheduled overnight**, identity.json build.
CPU idle/action/additional and matched warmed baseline comparison NOT RUN;
calibrated latency BLOCKED, [PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).
Baseline reference is preceding installed source with 100-unit spacing and
zoom-derived font size, not a timed run. No performance gain claimed.
Use synthetic/local fixtures only, respect prohibition on user screenshots.
Owned builds/tests complete; lease released; requested Release remains installed.
