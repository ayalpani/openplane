# Restore Overview captions

Shared header renderer accepts an explicit keep-visible policy for Overview stack headers. Existing zoom fade suppressed these captions at low overview fit scales. Same font, position and truncation retained, other view fading and stack movement unchanged.

Ten Overview tests PASS, including effective ancestor/text visibility for selected and unselected stacks at zoom 0.04, 0.08 and 0.2. Native synthetic scene visually inspected; AppKit has no Storybook. Signed Release build/signature PASS; installed AX launch Overview PASS. Personal window screenshots not inspected; live caption visual confirmation remains NOT RUN under that constraint.

P04/P20 full live input/core smoke/matched baseline **NOT RUN: scheduled overnight**; source/build in identity.json. Same first/warm fixture. Idle/action/additional CPU and presented latency NOT RUN. Safe visual fixture/calibrated observer **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No measured performance claim.
