# Review Desk

A local human-in-the-loop workspace: assignment → evidence → proposals → human
decision → work queue. Supports performance, reliability, usability and product
review requests. Custom requests wait for an agent; the implemented automatic
adapter is only the bounded OpenPlane performance pilot.

## Open

From the repository root, with Python 3.10+:

```sh
python3 review-desk/server.py
```

Visit **http://127.0.0.1:8766**. No package installation or public hosting is
required. The server listens only on loopback. Keep it running while using the
workspace; stop it with Control-C when finished.

## What actually works

- Read actual reports and raw data under `docs/performance/results/*/run.json`.
- See all 14 families, measured subsets, blocked coverage and stopped attempts.
- Review evidence, provenance, benefit, cost, functional contract and next step.
- Accept, reject, defer or request further investigation, with editable notes.
- Persist decisions atomically in `.state/decisions.json`, with revision checking
  and an append-only event history. Reloads and server restarts retain decisions.
- Derive a handoff queue with dependency information; export the whole workspace
  as JSON. Accepting a proposal **does not start implementation**.
- Save custom review requests as `Awaiting agent`.
- Start one bounded real UI pilot, follow progress and request cancellation.
  A filesystem lease prevents two pilots from controlling the Mac simultaneously.

## Live pilot

```sh
python3 scripts/run-performance-review.py \
  --output docs/performance/results/<unique-run-id>
```

The dashboard uses this same script. It executes subsets of P01, P02, P03, P05,
P06, P09 and P14, and records the missing pieces explicitly. P04/P07/P08/P10–P13
are not executed. It neither implements an S/R/L fixture nor claims complete
performance certification. A pilot with partial observations can be ready for
human review without any full runbook passing.

Use an unlocked test window with no other interaction. The pilot controls
OpenPlane, activates Finder, restarts OpenPlane and restores exported OpenPlane
preferences. It does not quit personal target apps, edit personal documents or
clear caches. A temporary preferences backup stays outside the repository and
is deleted only after successful restore. If restore fails, the report says so.
CPU comparison runs must not overlap compilation or browser automation.

Pilot measurements are current-build observations, not A/B results. Historical
navigator data is clearly marked as historical and its disabled-functionality
experiment remains an upper bound, not a production gain. AX polling timings
include script/observer latency and are not first-pixel/interaction-ready times.

## Verification

```sh
python3 -m unittest discover -s review-desk -p 'test_*.py'
```

Browser review must exercise filtering, case evidence, decision save/reload,
queue dependencies, rejection/revision, custom requests, export and narrow
layout. Use a temporary `--state-dir` and separate port for browser QA so test
clicks do not become the user's decisions. There is no Storybook in this
standalone HTML UI; inspect the real page and dialogs instead.

## Limitations and lifecycle

This is a local single-user decision workspace, not an authenticated team
service. Keep it on loopback. It has no external ticket connector, agent executor,
scheduler or merge/deployment capability. Queue entries are plans for handoff,
not a claim that an agent has been assigned. Unavailable server/save failures are
shown in the UI; decisions are acknowledged only after disk persistence succeeds.

If a runner is killed forcibly or the machine powers off, restoration may need
manual recovery from the temporary backup. Do not turn a stopped/blocked run into
a pass. No report or historical evidence is modified when changing a decision.

[Verification record and remaining limits](verification.md).

## Simplified decision list

The main view is a stable priority-sorted list. Expand a proposal for Analysis,
Assignment, Results and Proposed steps. Decisions and comments still persist with
an audit trail; earlier runs, new requests and raw evidence remain under disclosures.

“Discuss in Codex” copies the exact proposal, evidence, limitations, dependencies,
form decision and comment, plus repository/report paths, then opens the originating
conversation. Paste with Command-V and send there. This does not submit a message or
start an agent. If clipboard access fails, a dialog exposes the context for manual
copying. The existing-thread URL format was verified in the installed app bundle;
no undocumented prompt query parameter is used. The destination is this workspace’s
originating conversation, configured as `threadURL` in app.js.

Additional checks: `node --test review-desk/test_context.cjs`.
