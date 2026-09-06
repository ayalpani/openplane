# OpenPlane development requirements

## Performance is part of feature completion

- Follow [the performance policy](docs/performance/policy.md) for every change.
- Every new or changed user-visible function needs a live-UI performance case
  in [the runbooks](docs/performance/runbooks.md), including its alternate input
  paths, expected behavior, measurement boundaries and cache conditions.
- During interactive work, run fast relevant automated tests and a short live
  functional check of the changed behavior on the signed Release app installed
  in `/Applications`. Do not routinely run the full live suite or five-pair A/B
  campaigns for small changes while the user waits.
- Defer full live coverage, core smoke and repeated performance comparisons to
  the explicitly authorized nightly round (03:00 Europe/Berlin). Record deferred
  checks as `NOT RUN: scheduled overnight`, with the affected cases and source/
  build identity. Scheduling is not a pass. Full release requirements still apply.
  Unit tests supplement live tests; they do not replace them.
- Compare with a known baseline using the same fixture and measurement method.
  Report idle CPU, action CPU and additional CPU separately, and include latency
  and functional correctness. Never claim gains by disabling expected behavior.
- If tooling, fixture or access is missing, mark performance verification
  `BLOCKED` or `NOT RUN`, name the missing capability and link a follow-up task.
  Do not claim that the feature is fully performance-verified or silently waive
  the requirement. Documentation-only changes may be `NOT APPLICABLE`, with reason.
- Preserve raw evidence and complete a [report](docs/performance/report-template.md).
  Turn interpreted findings into deduplicated, bounded tasks in the
  [performance backlog](docs/performance/backlog.md). A fix requires a fresh
  before/after comparison and functional verification before the task is closed.
- Do not run competing builds, profilers or other agents' tests during a timed
  run. Restore the user's app/settings and terminate owned test jobs afterward.

The runbooks define the required process. Most live cases are not automated yet;
their documented existence is not evidence that tests ran. Do not create a
scheduler or launch an unattended agent loop merely because this process is
documented. The user explicitly authorized the nightly suite on 2026-09-06;
that scheduled verification is allowed, without automatic product changes.
Missing live automation capabilities remain open in the implementation backlog.
