# All apps: compact zoom, single-line captions

All apps hides dots and center guide without changing Canvas preferences.
Captions are single-line, end-truncated, fixed at 13pt. Opacity falls from 1 to 0
between zoom .85 and .55. Icons stop shrinking at 40pt; tiles shrink to icon+24pt,
with >=16pt gaps and responsive row-major reflow. Search/navigation use the same
frames. Launch failures also reach the status message when captions are hidden.

PASS: 11 focused chronological/catalog/order tests, including minimum icon/gap,
reflow geometry, actual layer caption truncation/opacity/compact frame height.
Synthetic normal and compact renders visually inspected: no user screenshots
viewed. Initial visual check caught CATextLayer default font-size mismatch;
explicit 13pt sizing corrected it before delivery. Signed Release build and
signature verification passed; candidate installed in /Applications.

Live attempt: app opened and AX controls read, but repeated user foreground/window
changes and noWindowsAvailable prevented stable catalog entry. No successful
live zoom check claimed. **BLOCKED**: exclusive stable live surface for P16;
follow-up [PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).
Avoid taking over the user's ongoing window navigation. Owned lease released;
no intentional settings changes. Full P16, affected P03/P07 and core smoke:
**NOT RUN: scheduled overnight**, candidate and baseline in identity.json.
Idle CPU, action CPU, additional CPU and matched warmed baseline latency:
**NOT RUN: scheduled overnight**. Calibrated visual latency remains BLOCKED
under PERF-022. Include wheel/pinch/keyboard zoom, scrolled/search/return/error
paths with identical synthetic fixture, plus first-process and warmed conditions.
No performance improvement or complete performance acceptance claimed.
