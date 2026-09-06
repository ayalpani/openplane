# Verification — 2026-09-05

## Actual OpenPlane pilot

[Report](../docs/performance/results/2026-09-05-review-004/report.md) ·
[raw observations and proposals](../docs/performance/results/2026-09-05-review-004/run.json)

The installed signed Release binary `e7980cfb…142277` was tested through real
keyboard input. Seven families have measured subsets: P01/P02/P03/P05/P06/P09/P14.
There are 40 observations: ten navigation trials and five each for zoom,
activation/return, process startup, desktop switching, search and idle.

All 14 families are displayed. Zero complete runbooks are certified: precise
latency/frame/correctness coverage, controlled fixtures and A/B pairs are still
missing. The other seven families were not executed. Tests did not modify the
native application code or install an experimental build. Original OpenPlane
preferences were imported after completion and the app binary hash was verified.

Preflight attempts 001–003 contain no measurement samples and remain marked
stopped. Initial Escape/reset handling and focus protection were investigated
before the completed series. These are runner setup events, not product
regressions. The user provided an exclusive live test window for the completed run.

No build, browser automation or CPU profiler ran during timed native phases.
User background applications remained active and the scene was not a frozen
S/R/L fixture; this limitation is recorded in the raw environment metadata.

## Dashboard correctness

Eight automated tests pass:

- Decisions survive restart and retain their prior state in the audit trail.
- Stale revisions and invalid states do not overwrite decisions.
- Custom requests are stored without executing their content.
- Failed disk persistence does not claim a successful decision.
- HTTP mutations require the local session token and reject foreign origins;
  evidence path traversal is rejected.
- One live pilot owner, cancellation flag and unexpected-exit recovery are checked
  with a test process substitute; no extra live pilot is launched by unit tests.
- Insufficient observations do not generate an investigation proposal.
- Findings are derived from observed CPU values and deduplicated on reanalysis.

The local HTTP server avoids reverse DNS on loopback. Its initial standard-library
hostname lookup delayed startup on this Mac; bypassing that unnecessary lookup
reduced the eight-test suite from 35.6 seconds to about 0.53 seconds. This is a
local tool correction, not an OpenPlane performance claim.

## Real browser verification

Used a separate QA server on port 8767 and isolated state directory, then verified
the untouched user workspace on port 8766. No QA decision or request was copied
into the user workspace.

Exercised through the visible DOM controls:

- Open proposal and read evidence, provenance, costs and functional contract.
- Accept/save, reload and inspect persisted queue entry.
- Revise to deferred, investigate, rejected and undecided; audit history retained.
- Navigator dependency remains explicit when measurement work is not accepted.
- Filter proposals by accepted state and restore the all-proposals view.
- Open measured startup evidence and blocked app-start coverage.
- Save a custom reliability request with literal HTML-like text; it stays text.
- Open the live-run explanation dialog and close it without starting a second run.
- Download/export data and verify decisions, notes, audit and request, without
  exposing the session token in the export.
- Inspect 1440×1000 and 390×844 layouts, including the decision form on narrow width;
  no page-level horizontal overflow. Browser error log was empty.

Screenshots inspected locally: `/tmp/openplane-review-wide.png`,
`/tmp/openplane-review-proposal.png`, `/tmp/openplane-review-mobile.png`,
`/tmp/openplane-review-mobile-decision.png`, `/tmp/openplane-review-user.png`.
QA screenshots may show test-only decisions; the final user screenshot has four
pending proposals and no decisions. No Storybook or prior UI baseline exists
for this new standalone page; current actual-page screenshots were reviewed.

Five loopback workspace reads, measured outside native CPU runs, took
2.37, 2.11, 2.12, 2.44 and 2.24 ms. This is API response/JSON-read timing only,
not a browser first-paint, tail-latency or full-dashboard performance certification.

## Handoff state

The normal installed OpenPlane binary remains unchanged. Native pilot jobs,
QA browser sessions and the QA server were stopped. Only the intentional local
Review Desk service on port 8766 remains running for the user. Four proposals
await human decisions. Approvals prepare handoff work; no implementation agent,
external ticket, scheduler, commit or merge is triggered automatically.

## Simplified list follow-up

Replaced sidebar, KPI tiles, cards and filter controls with one priority-sorted
proposal list. Each disclosure holds four content sections and a decision form.
Persistent requests/history/raw case evidence remain available under disclosures.
Eight Python checks and three JS context/order/escaping checks pass. Real browser
checks on isolated port 8767 verified accept+comment, reload persistence, then
reject+save (including updated row state). Desktop 1440×1000 and narrow 390×844
screenshots inspected; narrow status placement adjusted into a consistent grid.
No Storybook exists; these are actual-page checks. The initial agent-browser
follow-up clicks were ineffective after navigation; final save verification used
the in-app browser's accessibility controls and observed the saved confirmation.

Context copy succeeded in the first browser check. Tests verify exact evidence,
constraints, dependencies, form decision and question in the generated context.
The in-app browser security policy BLOCKED the subsequent Codex deep-link action;
it was not bypassed. End-to-end Codex navigation is therefore not certified.
No QA message was submitted to an agent. Existing-thread URL format is present in
the installed app bundle. Manual paste remains an explicit step, not auto-send.

Raw five-read server timing and scope: `simplification-check.json`. These reads
are warm loopback API latency only. Full CPU/input-to-pixel A/B comparison remains
BLOCKED pending an observer; see RD01 in the performance runbooks. No native app
code or binary was changed by this UI simplification.
