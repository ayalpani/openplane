# Return after close confirmation — 2026-09-10

After modal handoff, observe dismissal twice or process termination, reconcile
actual windows and reopen current OpenPlane view. Cancellation/new view/request
and deliberate switch to other app cancel return. AX unavailable is distinct
from no dialog. Existing overview layout and selection resolution reused.

Targeted WindowBackspaceActionTests/OverviewModeTests PASS, including regression
for unavailable AX process not counting as dismissed. Release build and strict
signature PASS. Live startup observed; end-to-end safe fixture NOT RUN due
repeated UI state/focus interruption; fixture also needs reliable host lifecycle.
No user previews inspected or user app confirmations accepted.

P11/P17 full variants/core smoke and matched idle/action/additional CPU,
pending-dialog overhead and latency NOT RUN: scheduled overnight.
Safe modal fixture/calibrated observer BLOCKED under
[PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance).
No full functional/performance acceptance claimed.

Animation feasibility inspection: right Command calls the normal toggle.
Canvas working-window return uses cameraAligning and animateCamera; automatic
views bypass it, restore layout and show overlay directly. Dismiss uses alpha
fade. Mission Control-like entry needs per-window real-screen start rects mapped
to target Overview rects, synchronized shared captions/selection and interruption
handling. Camera zoom alone cannot match individual real-window positions.
No animation implementation change in this revision.
