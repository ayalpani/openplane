# Music Backspace diagnosis — 2026-09-15

## Status and scope

P11/P17: INCONCLUSIVE for the reported intermittent failure. One live Backspace
succeeded on the installed Release app; no product code changed. Documentation
change performance: NOT APPLICABLE. No permanent fix or performance gain claimed.

## Environment and evidence

- Installed app: `/Applications/OpenPlane.app`, PID 636.
- Binary SHA-256: `ad9c59aa401b54a0910c087ec861f93537c8dc9b289476909f04c85c5e0c3808`.
- Workspace HEAD: `3d976d068ea1db08457d64dd71ad0f2b298248d8`, existing dirty
  workspace; installed binary's exact source correspondence not established.
- Existing Music process: PID 8703, Home window, no playback. Warm processes;
  no cache preparation. Overview, displayed zoom 0.28, empty search.
- Initial read-only AX query output: `pid 8703 inventory 0`, no window elements.
- After CUA read of Music: standard Music window with close button visible.
- Subsequent read-only AX query: `trusted true`, `com.apple.Music 0` and one
  AXUIElement for PID 8703.
- Live CUA sequence: Control-Option-Space, Up, Right. AX selected button Music.
  BackSpace once. Screenshot showed Music absent and Telegram selected.
- Process inventory afterward contained no `/Music.app/` process.

The original failure was not captured before inspecting Music. Reading its
accessibility tree may have initialized deferred accessibility information;
this is a hypothesis, not a proven cause. No screenshots with unrelated user
content retained in the repository. Raw tool outputs remain in the task.

## Measurement limits and follow-up

Idle CPU, action CPU, additional CPU, latency, memory and frame timings:
NOT RUN (functional diagnosis only). No paired comparison or calibrated observer.
No tests/builds required: product code unchanged. P11/P17 fresh-process Music
reproduction and full comparisons: NOT RUN: scheduled overnight, on the binary
identified above. Reliable reproduction remains open under PERF-025 in
[the backlog](../../backlog.md). Do not close that item from this one success.

## Cleanup

Music left terminated as requested. No settings changed, no owned background
jobs, no new app build installed. Overview remains open.
