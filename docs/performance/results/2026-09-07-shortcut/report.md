# Native overview shortcut and optional swipe prototype

Open overview in Settings records a persisted modified key, with cancel/reset
and registration error feedback. Carbon RegisterEventHotKey replaces the global
key monitor; a failed new registration preserves the existing binding. The
recorder temporarily unregisters the current hotkey and bypasses OpenPlane
navigation interception. Release tracking avoids repeated activation. Command-Tab
remains separate. Default is Control–Option–Space.

Optional, default-off Swipe up opens Overview uses local/global NSEvent swipe
monitors, without BTT or private APIs. Upward-dominant swipes select Overview;
other directions and scroll/pinch events do not. UI explicitly calls this
experimental and instructs freeing Mission Control's gesture first. Apple's
[monitoring documentation](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)
documents that global monitors cannot suppress normal event delivery. This is not
evidence that modern system-reserved physical gestures will be delivered.

## Evidence and limitations

PASS: 27 focused Overview/CanvasSelection tests including key validation,
serialization, swipe direction filtering and recorder presence. Synthetic empty
canvas/Settings render visually inspected. Signed Release built and verified.
Live: custom shortcut recorded, activated OpenPlane from Finder, reset and Escape
cancellation verified; [raw observations](live-observations.txt). No user-window
images inspected. Signature, source and binary identities accompany this report.

P19 physical built-in/Magic Trackpad acceptance is **BLOCKED** pending physical
input fixture/user test. Requested from user; not claimed passed. Follow-up
[PERF-024](../../backlog.md#perf-024--native-shortcuts-and-physical-swipe-acceptance).
Conflict/restart/held-key/keyboard-layout matrix, affected P01/P03/P17/P18 and core
smoke: **NOT RUN: scheduled overnight**, baseline/candidate in identity.json.
Idle CPU, action CPU, additional CPU and matched warm baseline latency:
**NOT RUN: scheduled overnight**. Missing calibrated latency/gesture adapters
remain BLOCKED. Use same synthetic fixture and observer for baseline/candidate;
first process separately from warmed conditions. No performance gain or full
release/performance acceptance claimed. No new scheduler created.

Build/test jobs completed, live lease released. Standard shortcut restored;
Settings remain open to let user test optional native swipe. Browser privacy
behavior unchanged by this work.
