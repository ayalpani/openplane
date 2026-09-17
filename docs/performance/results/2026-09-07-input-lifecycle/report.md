# Overview shortcut and window-first Backspace

Report ID: 2026-09-07-input-lifecycle. Overall performance status: **NOT RUN**;
short functional coverage passed as bounded below. Follow-up: [PERF-022](../../backlog.md#perf-022--chronological-mode-und-all-apps-vollständig-live-abnehmen).

Command-Tab now opens the overview in both modes. It no longer cycles windows
or activates a window on modifier release. Backspace closes the selected window
when more than one standard AX window exists, including minimized windows; only
an exactly known last window causes a regular application termination request.
Unknown AX inventory conservatively attempts window close. Search retains text
editing behavior. Canvas layouts and their persistence are unchanged.

## Identity and automated checks

[Build/source identities](identity.json), [source patch](source.patch),
[Release build log](build.log), [test log](tests.log).
31 relevant tests passed. Release build and installed signature verification passed.
The candidate executable SHA-256 is
`8d30f3a0a0da9100a375078a2de69b0928053d838d9ef13528d6dc760f627bc6`.
Baseline is the previously installed signed Release,
`d8faa750b021b48d78373d08c0197bd6c01c6d37f1efd7dd264c55866c3e10b3`.
Source HEAD and dirty patch hash are recorded in identity.json.

## Live functional observations

Performed with native CUA on the signed Release installed in `/Applications`,
under the exclusive live-test lease. [Raw notes](live-observations.txt) and
[disposable fixture source](Fixture.swift). Screenshots remain in the tool
transcript because they include private user previews.

- Baseline and candidate: one plain Down moved to the adjacent list entry. The
  reported double jump was not reproduced. Exact user modifier combination is
  still unknown; the new keyDown-only guard is defensive, not a proven fix.
- Candidate: two separate empty fixture windows, A and B. Backspace on A left
  only B visible and the fixture process running. Searching for B, leaving
  search with Escape and pressing Backspace terminated the fixture. Its own
  visibility probe and process existence corroborated the result. No user
  documents were closed. Automatic macOS window tabbing was disabled in fixture.
- A complete Command-Tab chord left the overview and same selected header
  visible after release. Repeated-chord coverage is **INCONCLUSIVE**: CUA also
  returned a timeout and noWindowsAvailable during this sequence. It must be
  repeated with controlled modifier-down/up input before full acceptance.

This is a short functional check, not a clean timing campaign. Ambient apps,
foreground changes, cache warmth and input timing were not controlled.

## Measurements and deferred coverage

| Measurement | Baseline | Candidate |
| --- | --- | --- |
| Idle CPU | NOT RUN | NOT RUN |
| Action CPU | NOT RUN | NOT RUN |
| Additional CPU | NOT RUN | NOT RUN |
| Reaction/target-ready latency | BLOCKED | BLOCKED |
| Frame timing, retained memory | NOT RUN | NOT RUN |

No numeric performance comparison or performance gain is claimed. A matched
fixture and warmed A/B sample is still required. Controlled modifier input and
calibrated latency observers remain **BLOCKED**, tracked by PERF-022.

**NOT RUN: scheduled overnight** — P15 shortcut repetition/release/cancellation,
all arrow modifier/repeat variants; P11/P16 minimized and off-Space sibling
windows, missing AX, save dialogs, application refusal to terminate; affected
P01/P03 navigation/core smoke and repeated CPU comparisons. Run against the
candidate/source identities above in the existing authorized 03:00 Europe/Berlin
round. Scheduling is not a pass; no new scheduler was created.

## Cleanup

Fixture process terminated through the tested last-window action. Build/test
processes completed; exclusive lease released. No Settings toggles were changed
in this check. Selection/camera moved during navigation, as normal use does.
The requested signed Release remains installed. Full performance and the user's
unreproduced double-jump report remain open.

## Reopened: user still observes double jump

The user explicitly reports the symptom remains. No fix is claimed. A signed
Release with opt-in arrow-only OSLog diagnostics is now installed; its identity
supersedes the earlier candidate for overnight testing:
[diagnostic identity](diagnostic-identity.json),
[diagnostic patch](diagnostic-source.patch), [build](diagnostic-build.log).
The [arrow event trace](arrow-trace.log) records key code/modifiers/repeat state,
list index and camera/target Y, with no window titles or typed text. Captured
Down/Up events each changed the list index by one; release did not advance it.
This does not establish visual correctness. Clarification remains pending on
whether an actual window is skipped or the camera makes two visible movements.
The log-stream process was stopped and the diagnostic preference removed for
subsequent launches. The current diagnostic process retains its startup flag
until restart. Diagnostic runs are not CPU measurements; no performance pass.

User follow-up: plain Up/Down, no modifier; after the diagnostic Release restart
“Jetzt ist der zweiersprung weg, ka warum”. Diagnostic code does not alter
navigation decisions. Symptom currently absent, root cause unconfirmed. Track
reopening/repeated mode changes and retained camera/selection state in PERF-022;
do not present the diagnostic rebuild as a proven behavioral fix.
