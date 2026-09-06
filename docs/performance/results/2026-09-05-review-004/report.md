# OpenPlane performance review

Run: `2026-09-05-review-004`

Single-build live pilot; no A/B claim and no full 14-case certification.

Status: review

| Case | Status | Evidence / limitation |
| --- | --- | --- |
| P01 Arrow navigation | partial | CPU measured on two desktops, five trials each, two warm-up bursts per desktop. No per-trial camera/selection reset, fixed target oracle, cold/A-B comparison or frame/latency observer. |
| P02 Zoom | partial | Keyboard-tap zoom CPU sampled. Final persisted zoom recorded. Full bounds, held-key/pinch behavior, ten-cycle runbook and image quality are not certified. |
| P03 Activate and return | partial | Five real Finder activations and returns verified by foreground app. Coarse script/AX timings include observer overhead; they are not first-frame or usability latency. Other apps and input paths remain untested. |
| P04 Launch closed apps | blocked | A disposable multi-app fixture and per-app ready criteria are not available. No personal apps were quit. |
| P05 OpenPlane startup | partial | Five process starts to accessible canvas title. Not a presented-first-frame, full-preview or interaction-ready measurement; OS caches uncontrolled. |
| P06 Desktop switching | partial | CPU for 30 real Tab inputs per trial. Final desktop recorded; accepted-event count and transition latency not observed. Rapid and mouse variants remain untested. |
| P07 Pan, minimap and saved view | blocked | Repeatable pointer/trackpad routes and camera end-state observer are missing. |
| P08 Move and group cards | blocked | A disposable layout plus group/drag end-state observer is missing. Personal arrangements were preserved. |
| P09 Search | partial | Search interaction CPU measured; query/selection visual oracle and per-keystroke latency missing. No pass claim for search correctness. |
| P10 Window discovery and previews | blocked | A controlled changing-window source and preview-freshness observer are missing. |
| P11 Quit selected app | blocked | Safe disposable app/document fixture is missing. Personal apps were not quit. |
| P12 Edit and persist desktops | blocked | A disposable profile and persistence assertions are missing. Personal desktops were not edited. |
| P13 Settings and shortcuts | blocked | The settings variant manifest and visual expectations are not yet implemented. |
| P14 Idle and sustained use | partial | 60 seconds of visible idle in five windows. No long mixed-use, background, leak/footprint or wakeup coverage. |

Raw evidence: [run.json](run.json)

No feature changes were made by this pilot. Decisions are recorded separately by Review Desk.

## Observed results

Current-build pilot, no A/B regression or gain claim. CPU is OpenPlane only; 100% is one CPU core.

| Case | Samples | Action CPU median | Idle before median | Median extra CPU |
| --- | ---: | ---: | ---: | ---: |
| P01 Arrow navigation | 10 | 8.72% | 1.14% | 7.50 pp |
| P02 Zoom | 5 | 31.36% | 1.15% | 30.24 pp |
| P06 Desktop switching | 5 | 13.12% | 1.04% | 11.90 pp |
| P09 Search | 5 | 5.65% | 1.05% | 4.54 pp |

Different event cadences and scenes prevent a like-for-like efficiency comparison.

OpenPlane launch → accessible canvas title: mean 0.610 s, median 0.620 s, range 0.573–0.630 s across five process starts. Includes command/polling overhead; not first-frame or full-readiness time.
Visible idle: median 1.02% over five 12-second intervals.

## Proposed decisions

### Investigate CPU work during zoom

5 samples: median action CPU 31.36%, idle before 1.15%; median per-trial additional CPU 30.24 percentage points. Different action cadences prevent a like-for-like ranking of implementation efficiency.

Proposed next step: Profile P02 separately from timed runs; connect expensive work to code, capture response/frame timing, then propose a bounded fix with an A/B acceptance test.

Trade-off: A focused profile and controlled reproduction first; no product change is proposed yet.

### Reuse the navigator’s rendered app content

Historical two-trial ablation: 8.16 → 5.19% and 7.78 → 4.93%. Not a result of this pilot and not an achievable-gain guarantee.

Proposed next step: Implement a bounded prototype, then run P01/P03/P07/P13 A/B comparisons with unchanged functionality.

Trade-off: Some cache memory and invalidation logic.

### Make latency and correctness measurable

All executed subsets still lack at least one required latency, presented-frame or correctness observer.

Proposed next step: Pilot a calibrated event-to-visible-result observer for P01/P03/P05; preserve raw events and add functional assertions.

Trade-off: Instrumentation and calibration work; observer overhead must be measured.

### Create disposable app and desktop test scenes

P04/P07/P08/P10/P11/P12/P13 are not executed in this pilot; reasons are recorded per case.

Proposed next step: Build S/R fixtures, verify reset twice, then implement the repeated/same/different/all-app P04 route.

Trade-off: Maintain manifests, dummy documents, state reset and per-app readiness rules.

## Completion

Preferences restored: True. All pilot subprocesses completed. No product code was changed by this run. Decisions are pending; approving a proposal in Review Desk prepares a handoff, not automatic implementation.

Runner limitation: early preflight attempts 001–003 were stopped before collecting samples (focus/reset handling and intentional harness corrections). They are retained as stopped runs, not product failures.
