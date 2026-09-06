# Retained canvas rendering — September 5, 2026

Latest installed-build result: median navigation CPU is **8.40% on Hahaha** and
**7.88% on Desktop 2**, versus 24.04% and 16.04% in the preceding build. The native
camera comparison at the end of this report separates idle and navigation CPU.

## Change

Cards now live in a shared Core Animation camera layer. Panning updates its
transform and reuses card contents. Fixed-zoom keyboard travel uses an explicit
Core Animation transform animation; the display link keeps the logical camera,
grid phase and minimap in sync for interaction. Selection updates only border
and title layer properties. Preview images change only when their source changes.

The background grid and fixed HUD are separate from the cards. The minimap's
viewport is a shape layer; its map is redrawn if the projection changes. Zoom
retains the existing screen-size rules for headers, borders and closed-card
labels, so zoom still updates card geometry. No new dependencies or persisted
schema changes were introduced.

## Live measurements

Installed signed Release builds on the same Mac, macOS 26.6.2, main display
3456 × 2234 pixels. Both OpenPlane desktops were exercised using real macOS key
events: 25 repetitions of Right, Down, Left, Up with an 80 ms requested pause
between keys (100 keys took 8.9–9.0 seconds including event-delivery overhead).
The updated renderer was measured three times per desktop. CPU percentages use
100% for one CPU core. Medians below use the six central one-second samples,
excluding startup and the idle tail.

| Desktop | New renderer: run 1, with sampler | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| Hahaha, zoom 0.17 | 18.95% | 16.30% | 16.30% |
| Desktop 2, zoom 0.09 | 21.95% | 18.90% | 19.00% |

A fresh pre-change installed-build measurement on Desktop 2 yielded 51.85%
median CPU under the same key sequence and sampling method. The initial
investigation measured approximately 40–68% on Hahaha. These are indicative live
comparisons: app contents continue changing, and restarting can rearrange
unmanifested windows, so they are not a frozen-scene microbenchmark.
Repeated new-renderer runs showed no progressive memory growth; the process
returned to roughly 1% CPU after the navigation burst.

## Animation profiling

Xcode Instruments' Animation Hitches template recorded 18 seconds per renderer.
The older renderer was rebuilt from the pre-change CanvasView with the other
current source files, in a temporary build directory. Both recordings used a
longer route: four keys in each direction, then Tab, repeated three times.
Only hitch rows attributed to OpenPlane were counted.

| Instruments result | Previous renderer | Retained renderer |
| --- | ---: | ---: |
| Reported hitches | 534 | 337 |
| Sum of hitch durations | 5,045.75 ms | 2,949.96 ms |
| Longest reported hitch | 75.00 ms | 41.67 ms |

This is about 37% fewer reported hitches and 42% less accumulated hitch duration.
Hitches are **not eliminated**. Most reported durations are one 8.33 ms display
interval. These numbers are Instruments hitch metrics, not key-to-pixel latency
or an assertion of perfect 120 fps. Recording itself also adds overhead.

## Regression checks

- All 78 existing and added tests passed in an isolated preferences domain.
- Added tests verify that 100 camera translations preserve card-layer identity,
  do not prepare card content again, and agree with the existing world-to-screen
  geometry. Zoom tests preserve identity and coordinate scaling.
- Live checks covered both desktops, rapid direction changes, longer routes,
  Shift-Return group selection, keyboard zoom, Return into Ollama and
  Control-Option-Space back to OpenPlane with a refreshed preview.
- Native screenshots were inspected for cards, titles, icons, selection,
  background grid and minimap. This AppKit project has no Storybook surface.

The implementation removes full-card redraws from ordinary camera translation.
Remaining work includes CPU-side animation/state coordination and compositor
cost; the measurements do not support claiming zero CPU usage or zero hitches.

## Follow-up: selection animation and deferred maintenance

Selection borders and titles now use explicit Core Animation keyframes instead
of a selection display-link callback. Existing transition phases are sampled
once per selection change, without mutating live layers while sampling. Constant
tracks are omitted; interrupted animations start at their presentation values.
Camera movement starts one deferred maintenance job, which persists the final
camera and refreshes tooltip regions after movement has stopped. Explicit saves
still persist immediately.

The follow-up comparison uses the signed installed build at commit `0970714`
as its baseline and the updated signed Release build. Both start from the same
exported preferences, with zoom 0.16554 on Hahaha and 0.56273 on Desktop 2.
Each build runs three 100-key bursts per desktop using the same real key events
and central-six-sample CPU method above. Earlier exploratory follow-up numbers
are excluded because Desktop 2's zoom changed between those measurements.
Live window contents and unmanifested window placement can still vary across
restarts; this is a live-app comparison, not a frozen-scene benchmark.

| Desktop | Baseline run medians | Updated run medians | Median change |
| --- | --- | --- | --- |
| Hahaha | 22.85%, 29.75%, 26.85% | 23.75%, 22.80%, 25.20% | 26.85% → 23.75% (−11.5%) |
| Desktop 2 | 19.75%, 19.30%, 19.30% | 16.65%, 16.35%, 16.40% | 19.30% → 16.40% (−15.0%) |

Each burst took 9.46–10.38 seconds on Hahaha and 8.84–9.03 seconds on Desktop 2.
Hahaha's run-to-run ranges overlap, so its improvement is indicative, not a
statistically established speedup. CPU here remains OpenPlane process CPU,
with 100% representing one core; it does not measure GPU or WindowServer cost.
The raw follow-up summaries are saved alongside this report in
`selection-animation-cpu.json`.

All 79 tests pass, including a regression that verifies 100 camera updates
schedule one maintenance job, defer persistence, and ultimately save the final
camera. Preference-dependent view fixtures run serially in an isolated bundle
domain. A separate 12-second CPU sample during real navigation contains camera
display-link work and Core Animation transaction commits, with no selection
display-link callback. These remaining costs have not been removed.
Live checks also exercised rapid reversals, group selection and keyboard zoom;
native screenshots were inspected for the final selection border and title.

## Further reduction: native camera flights

The next change removes two remaining sources of navigation work:

- The grid previously stored tens of thousands of ellipse paths at overview
  zoom. It now repeats a small rasterized tile through Core Animation replicators.
  Tile dimensions stay near 256 logical points even at high zoom. Invisible grid
  zoom levels do not prepare a tile.
- Ordinary fixed-zoom camera flights now animate the shared camera transform,
  grid position, minimap content transform and minimap viewport together. There
  is no camera display-link callback on this path. The current logical camera is
  evaluated on demand, and one delayed completion finalizes the flight. Zoom,
  focus transitions and group overlays retain their existing frame coordination.

Selection changes update affected cards without invalidating the HUD when there
is no group/search overlay. The minimap uses retained shape layers. Normal and
bold title variants retain their rendered contents; unchanged selection shadow
paths and the lock icon are reused. Arrow-key changes share one outer Core
Animation transaction. Desktop bounds for minimap keyframes are computed once
per flight.

`scripts/measure-navigation.py` measures five seconds idle, 100 real arrow keys,
one second settling, then five seconds idle again. It reads cumulative macOS
process CPU time at phase boundaries instead of continuously running `top`.
Mach ticks are converted using the host's timebase; a self-check compares the
result with Python's independent process CPU clock. Locked sessions are rejected.
Unlike the earlier central-sample medians, these are averages over each complete
phase, so compare builds using this same script.

Both signed Release builds started from the same exported desktop preferences
(zoom 0.16554 on Hahaha and 0.56273 on Desktop 2). Three trials per desktop and
build produced these phase medians:

| Desktop / build | Idle before | Navigation | Settling | Idle after |
| --- | ---: | ---: | ---: | ---: |
| Hahaha / previous | 0.98% | 24.04% | 4.21% | 0.84% |
| Hahaha / updated | 1.03% | 8.40% | 1.37% | 0.94% |
| Desktop 2 / previous | 1.08% | 16.04% | 2.09% | 1.08% |
| Desktop 2 / updated | 1.11% | 7.88% | 1.48% | 1.10% |

Navigation CPU fell by **65.1% on Hahaha** and **50.9% on Desktop 2**. Every
updated trial was below half of every previous trial on its corresponding
desktop. The three updated navigation averages were 8.10%, 8.40%, 8.40% and
7.80%, 7.90%, 7.88%, respectively. Raw per-phase CPU times, wall times and
percentages are in `native-navigation-cpu.json`.

Requested key spacing stayed at 80 ms. Including event delivery, 100-key bursts
took 10.15–10.19 seconds before and 9.50–9.60 seconds after on Hahaha;
9.56–9.83 seconds before and 9.49–9.56 seconds after on Desktop 2. No build,
`top` or CPU profiler ran during these comparison measurements. These remain
live-window results, not a frozen scene or a measurement of WindowServer/GPU
cost. 100% is one CPU core, not the whole machine.

82 regression tests pass, including native flight completion, interruption,
direct camera assignment, persistence during a flight, window resizing, zero
camera frame callbacks for ordinary travel, unchanged prepared title contents,
and unaffected-card update counts. Final live checks covered both desktops,
rapid reversals, group selection, keyboard zoom, Return into Slack and
Control-Option-Space back into OpenPlane. Native screenshots were inspected for
titles, borders, grid and minimap. This native AppKit project has no Storybook.
A separate diagnostic sample of the native camera implementation confirmed that
ordinary navigation no longer called the camera or selection display-link
callbacks; it identified the repeated shadow-path and lock-SVG work subsequently
removed. An attempted measurement during a locked session was excluded.


## Follow-up: interrupted camera flights must preserve zoom

A fresh navigation profile found `stepCameraAnimation` and repeated full scene
synchronization during rapid reversals, despite ordinary translations being
eligible for native animation. Reading the presentation layer's affine transform
can round its scale: the regression fixture changed 0.1655411772 into
0.16554117719999997. The strict fixed-zoom check then chose the CPU zoom path.

Interrupted native translations now retain the logical zoom while taking their
position from the presentation layer. Actual zoom transitions still read the
presentation scale. This fixes the cause rather than treating small intentional
zoom changes as translations.

The new regression test uses a displayed window, a non-binary zoom and six rapid
reversals. Before the fix it failed with 31 camera frame callbacks and additional
content preparation; after the fix it passes with zero camera callbacks and
unchanged prepared contents. All 83 tests pass in the serial Debug suite.

The installed signed Release comparison used identical exported preferences for
both fresh launches (Hahaha zoom 0.16554117722696848; Desktop 2 zoom
0.38125000000000003), with three 100-key trials per desktop. No compiler or
profiler ran during the CPU measurements. Phase medians:

| Desktop / build | Idle before | Navigation | Settling | Idle after |
| --- | ---: | ---: | ---: | ---: |
| Hahaha / previous | 0.94% | 8.39% | 1.19% | 0.97% |
| Hahaha / fixed | 2.54% | 8.25% | 1.31% | 0.95% |
| Desktop 2 / previous | 0.98% | 7.79% | 1.42% | 0.86% |
| Desktop 2 / fixed | 0.94% | 7.68% | 1.35% | 0.95% |

Navigation differences (about 1–2%) overlap run-to-run variation; this does **not**
establish another reduction in average CPU usage. The change prevents a
reproduced fallback at susceptible zoom values. Some idle phases included brief
background work (up to 2.76%); raw phase data is in
`camera-interruption-cpu.json`. These live scenes differ from the earlier
native-camera comparison, so use the matched before/after pair above.

A separate post-fix Release sample after real keyboard zoom and rapid arrow-key
reversals contained no `stepCameraAnimation` callbacks. Remaining sampled work
was in per-key selection changes, Core Animation commits and navigator updates.
The native screenshot was inspected for the grid, yellow selection border,
titles and minimap. Test view settings were restored afterward; all measurement,
profiling and build processes had finished.


## Next candidate: navigator updates (diagnostic ablation)

The post-fix sample includes navigator title/icon assignments, AppKit layout and
Core Animation drawing/commit work. To measure the whole navigator update path,
a temporary Release variant returned immediately from `updateNavigatorPanel`
after the first displayed content. This deliberately leaves navigator controls
stale; it is not a viable product change. Camera travel, minimap and card selection
continue normally. The original source and installed signed app were restored
after the experiment.

Two 100-key trials per desktop per variant, each with idle phases before/after,
used the same exported preferences and fresh launches. No build or profiler ran
during measurements. Navigation phase medians (100% = one CPU core):

| Desktop | Normal | Frozen navigator | Reduction |
| --- | ---: | ---: | ---: |
| Hahaha | 8.16% | 5.19% | 36.4% |
| Desktop 2 | 7.78% | 4.93% | 36.6% |

Both diagnostic trials were substantially below both control trials on each
desktop. Raw data: `navigator-diagnostic-cpu.json`. This isolates roughly three
CPU percentage points attributable to the navigator update path and its induced
rendering/layout in this live scenario. It does not isolate the fade, icon,
title, tooltip or accessibility work individually, and the observed reduction
is an upper bound rather than a promised improvement with full behavior retained.

Next implementation candidate: retain rendered app title/icon content, avoid
resetting unchanged control properties and update by displayed app content
rather than window ID where the visible title/icon are identical. Preserve
click actions, hover previews and accessibility. If AppKit button redraw remains
expensive, use retained title/icon layers for its visual content and keep native
control interaction/accessibility. Measure the complete implementation against
the normal build before calling it a performance gain.
