# Retained canvas rendering — September 5, 2026

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
