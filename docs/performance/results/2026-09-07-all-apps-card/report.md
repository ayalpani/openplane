# All apps card — 2026-09-07

Compact internal icon/label composition replaces the preview header and truncated
subtitle. Card is centered on the existing list axis, with a 2-point yellow
selection border. Existing catalog navigation is reused.

Identity: [source/build](identity.json), [patch](source.patch), [build log](build.log),
[test log](tests.log). Two ChronologicalModeTests passed; signed Release installed
in `/Applications/OpenPlane.app`, signature verified.

Short CUA functional/visual check under exclusive live-test lease: searched
All apps, dismissed search, saw centered white icon and complete label with no
outside header/subtitle. Smaller zoom 0.20 and increased zoom were checked;
screenshots are in the tool transcript only because other previews are private.
Return opened the alphabetical catalog (Activity Monitor first, Back button
visible); Escape restored All apps selection. Multiple initial attempts were
invalidated by noWindowsAvailable/user-changed-state responses; those are not
successful checks. No timing claims from CUA action durations.

Baseline is the user-supplied screenshot and previous installed diagnostic binary;
not a matched warmed performance trial. Idle CPU, action CPU and additional CPU:
**NOT RUN: scheduled overnight**, P16 card selection/zoom/Return/click variants,
P03 affected zoom smoke, against identity.json. Precise reaction/target-ready
latency **BLOCKED** by missing calibrated observers: [PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).
No numerical gain or full performance pass claimed. Full click and extreme zoom
coverage remains overnight work. Existing authorized schedule only.

Build/tests complete; no user document changed. New Release remains installed.
