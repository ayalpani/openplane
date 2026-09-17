# First-class views and constrained OpenAI prompt prototype

Floating Views overlay exposes the four existing views, with persisted names and
manual movement permission per view. Overview defaults off; All apps defaults to
bounded vertical scrolling and no horizontal pan from every entry mode. Pinch
uses viewport center when manual movement is off. Camera follows selection is a
separate setting. All apps no longer writes catalog camera state to Canvas desktop
storage. Overlay area is excluded from Overview and catalog placement.

Prompt prototype persists text per view and requests only name/layout/pan/follow
from OpenAI Responses with strict JSON Schema, gpt-5-mini, store=false, 1200 output
tokens, minimal reasoning, 30s timeout and ephemeral URLSession. Key is only from
app environment or secure session field, never persisted/logged. No window data,
images, app inventories, privacy/permission changes, arbitrary code or extra view
instances are part of this prototype. Suggestions require explicit Apply. View
switch cancels/discards pending suggestions. Validate layout/name before applying.

## Evidence

33 relevant tests passed: per-view defaults, pan behavior, catalog scroll and
entry origins, overlay names, constrained plan validation/apply, text editor
navigation isolation, and existing Overview/Chronological/selection regression
checks. Native Settings and synthetic catalog renders visually inspected. Initial
black-on-black overlay styling fixed with dark appearance. Final standard Edit
menu and Command-A verified live. Signed Release built/verified/installed.

Real API smoke used production client with a synthetic prompt; valid parsed result
in api-synthetic-response.json. Installed UI Generate → suggestion → Apply → label/
checkbox update completed. No user screenshots viewed. The initial model-access
failure was diagnosed, not hidden; current allowed model succeeded. See
[live observations](live-observations.txt), [identity](identity.json), [tests](tests.log),
[build](build.log), [source](source.patch), [Settings](settings-synthetic.png).

API references: [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs),
[GPT-5 mini](https://developers.openai.com/api/docs/models/gpt-5-mini).

## Performance and pending acceptance

P20/P21 and affected P03/P07/P15–P18/core smoke: **NOT RUN: scheduled overnight**,
with source/build and baseline identities above. Full mixed-display/pinch/minimap,
long-name, rename/restart, request failure/refusal/timeout/stale-response matrix
remains pending. Use identical synthetic fixture and measurement method for both
builds, first-process and warm conditions separately. Idle CPU, action CPU,
additional CPU and matched baseline latency: **NOT RUN: scheduled overnight**.
Deterministic response fixture/calibrated latency observer: **BLOCKED**, follow-up
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
Remote API latency was not measured as a performance benchmark. No gains or full
performance acceptance claimed. Existing nightly authorization only; no scheduler.

Owned build/test jobs completed; live lease released. Initial Chronological view
restored; Overview name restored and useful sample prompt retained. API key remains
in this running process environment only. Normal Finder relaunch may require a
session key entry or launching with OPENAI_API_KEY; durable credential setup is
outside this primitive experiment.
